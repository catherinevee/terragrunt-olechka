#!/usr/bin/env python3
"""
Terraform Module Dependency Analyzer

This script analyzes Terraform configurations to:
1. Parse Terraform configurations using hclparse
2. Extract module blocks and their dependencies
3. Build dependency graphs
4. Detect circular dependencies
5. Generate visualizations (DOT, Mermaid, HTML)

Usage:
    python terraform-dependency-analyzer.py [--path PATH] [--output OUTPUT] [--format FORMAT]
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional, Any
from collections import defaultdict, deque
import hcl2
import networkx as nx
from dataclasses import dataclass, field
import re


@dataclass
class ModuleInfo:
    """Represents a Terraform module with its dependencies"""
    name: str
    source: str
    path: str
    variables: Dict[str, Any] = field(default_factory=dict)
    outputs: List[str] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    terragrunt_dependencies: List[str] = field(default_factory=list)


@dataclass
class DependencyGraph:
    """Represents the dependency graph of modules"""
    modules: Dict[str, ModuleInfo] = field(default_factory=dict)
    graph: nx.DiGraph = field(default_factory=lambda: nx.DiGraph())
    circular_dependencies: List[List[str]] = field(default_factory=list)


class TerraformDependencyAnalyzer:
    """Main analyzer class for Terraform module dependencies"""
    
    def __init__(self, root_path: str):
        self.root_path = Path(root_path)
        self.dependency_graph = DependencyGraph()
        self.terragrunt_files = []
        
    def find_terragrunt_files(self) -> List[Path]:
        """Find all terragrunt.hcl files in the directory tree"""
        terragrunt_files = []
        for file_path in self.root_path.rglob("terragrunt.hcl"):
            terragrunt_files.append(file_path)
        return terragrunt_files
    
    def parse_terragrunt_file(self, file_path: Path) -> Optional[ModuleInfo]:
        """Parse a terragrunt.hcl file and extract module information"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Parse HCL2 content
            parsed = hcl2.loads(content)
            
            module_info = ModuleInfo(
                name=file_path.parent.name,
                source="",
                path=str(file_path.parent)
            )
            
            # Extract terraform source
            if 'terraform' in parsed:
                terraform_block = parsed['terraform'][0]
                if 'source' in terraform_block:
                    module_info.source = terraform_block['source']
            
            # Extract dependencies
            if 'dependency' in parsed:
                for dep in parsed['dependency']:
                    for dep_name, dep_config in dep.items():
                        if 'config_path' in dep_config:
                            # Extract the module name from the config path
                            config_path = dep_config['config_path']
                            # Handle relative paths like "../../network/vpc"
                            if config_path.startswith('../../'):
                                parts = config_path.split('/')
                                if len(parts) >= 2:
                                    module_name = parts[-1]  # Get the last part
                                    module_info.terragrunt_dependencies.append(module_name)
            
            # Extract inputs (variables)
            if 'inputs' in parsed:
                module_info.variables = parsed['inputs']
            
            return module_info
            
        except Exception as e:
            print(f"Error parsing {file_path}: {e}")
            return None
    
    def parse_terraform_files(self) -> None:
        """Parse all Terraform .tf files in the directory tree"""
        for file_path in self.root_path.rglob("*.tf"):
            if file_path.name != "terragrunt.hcl":
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    parsed = hcl2.loads(content)
                    
                    # Extract module blocks
                    if 'module' in parsed:
                        for module_block in parsed['module']:
                            for module_name, module_config in module_block.items():
                                module_info = ModuleInfo(
                                    name=module_name,
                                    source=module_config.get('source', ''),
                                    path=str(file_path.parent)
                                )
                                
                                # Extract variables
                                if 'variables' in module_config:
                                    module_info.variables = module_config['variables']
                                
                                # Extract dependencies from variable references
                                self._extract_variable_dependencies(module_info, module_config)
                                
                                self.dependency_graph.modules[module_name] = module_info
                    
                    # Extract outputs
                    if 'output' in parsed:
                        for output_block in parsed['output']:
                            for output_name, output_config in output_block.items():
                                if 'value' in output_config:
                                    # Check if output references other modules
                                    value_str = str(output_config['value'])
                                    self._extract_output_dependencies(value_str)
                    
                except Exception as e:
                    print(f"Error parsing {file_path}: {e}")
    
    def _extract_variable_dependencies(self, module_info: ModuleInfo, module_config: Dict) -> None:
        """Extract dependencies from variable references in module configuration"""
        config_str = str(module_config)
        
        # Look for references to other modules (e.g., module.vpc.id)
        module_refs = re.findall(r'module\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)', config_str)
        for ref_module, ref_output in module_refs:
            if ref_module != module_info.name:
                module_info.dependencies.append(ref_module)
    
    def _extract_output_dependencies(self, value_str: str) -> None:
        """Extract dependencies from output value references"""
        module_refs = re.findall(r'module\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)', value_str)
        for ref_module, ref_output in module_refs:
            # Add to the module's outputs list
            if ref_module in self.dependency_graph.modules:
                if ref_output not in self.dependency_graph.modules[ref_module].outputs:
                    self.dependency_graph.modules[ref_module].outputs.append(ref_output)
    
    def build_dependency_graph(self) -> None:
        """Build the NetworkX dependency graph"""
        # Add nodes for all modules
        for module_name, module_info in self.dependency_graph.modules.items():
            self.dependency_graph.graph.add_node(module_name, module_info=module_info)
        
        # Add edges for dependencies
        for module_name, module_info in self.dependency_graph.modules.items():
            # Add edges for Terraform module dependencies
            for dep in module_info.dependencies:
                if dep in self.dependency_graph.modules:
                    self.dependency_graph.graph.add_edge(dep, module_name)
            
            # Add edges for Terragrunt dependencies
            for dep in module_info.terragrunt_dependencies:
                if dep in self.dependency_graph.modules:
                    self.dependency_graph.graph.add_edge(dep, module_name)
    
    def detect_circular_dependencies(self) -> List[List[str]]:
        """Detect circular dependencies using NetworkX"""
        try:
            cycles = list(nx.simple_cycles(self.dependency_graph.graph))
            self.dependency_graph.circular_dependencies = cycles
            return cycles
        except nx.NetworkXNoCycle:
            return []
    
    def generate_dot_graph(self) -> str:
        """Generate DOT format for Graphviz"""
        dot_content = ["digraph G {"]
        dot_content.append("  rankdir=TB;")
        dot_content.append("  node [shape=box, style=filled, fillcolor=lightblue];")
        dot_content.append("  edge [color=gray];")
        
        # Add nodes
        for module_name, module_info in self.dependency_graph.modules.items():
            dot_content.append(f'  "{module_name}" [label="{module_name}\\n{module_info.source}"];')
        
        # Add edges
        for edge in self.dependency_graph.graph.edges():
            source, target = edge
            dot_content.append(f'  "{source}" -> "{target}";')
        
        # Highlight circular dependencies
        if self.dependency_graph.circular_dependencies:
            dot_content.append("  edge [color=red, penwidth=2];")
            for cycle in self.dependency_graph.circular_dependencies:
                for i in range(len(cycle)):
                    source = cycle[i]
                    target = cycle[(i + 1) % len(cycle)]
                    dot_content.append(f'  "{source}" -> "{target}" [color=red, penwidth=2];')
        
        dot_content.append("}")
        return "\n".join(dot_content)
    
    def generate_mermaid_diagram(self) -> str:
        """Generate Mermaid diagram format"""
        mermaid_content = ["graph TD"]
        
        # Add nodes
        for module_name, module_info in self.dependency_graph.modules.items():
            mermaid_content.append(f'    {module_name}["{module_name}<br/>{module_info.source}"]')
        
        # Add edges
        for edge in self.dependency_graph.graph.edges():
            source, target = edge
            mermaid_content.append(f'    {source} --> {target}')
        
        # Add circular dependency warning
        if self.dependency_graph.circular_dependencies:
            mermaid_content.append("    %% Circular Dependencies Detected!")
            for cycle in self.dependency_graph.circular_dependencies:
                cycle_str = " -> ".join(cycle)
                mermaid_content.append(f'    %% Cycle: {cycle_str}')
        
        return "\n".join(mermaid_content)
    
    def generate_html_visualization(self) -> str:
        """Generate interactive HTML visualization using vis.js"""
        html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>Terraform Module Dependency Graph</title>
    <script type="text/javascript" src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>
    <style type="text/css">
        #mynetworkid {
            width: 100%;
            height: 800px;
            border: 1px solid lightgray;
        }
        .controls {
            margin: 20px 0;
            padding: 10px;
            background-color: #f5f5f5;
            border-radius: 5px;
        }
        .circular-warning {
            color: red;
            font-weight: bold;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <h1>Terraform Module Dependency Graph</h1>
    
    <div class="controls">
        <button onclick="network.fit()">Fit to Screen</button>
        <button onclick="network.stabilize()">Stabilize</button>
        <button onclick="togglePhysics()">Toggle Physics</button>
    </div>
    
    <div id="mynetworkid"></div>
    
    <script type="text/javascript">
        // Create nodes
        var nodes = new vis.DataSet([
            {nodes_data}
        ]);
        
        // Create edges
        var edges = new vis.DataSet([
            {edges_data}
        ]);
        
        // Create a network
        var container = document.getElementById('mynetworkid');
        var data = {
            nodes: nodes,
            edges: edges
        };
        var options = {
            nodes: {
                shape: 'box',
                font: {
                    size: 14
                },
                borderWidth: 2,
                shadow: true
            },
            edges: {
                width: 2,
                shadow: true,
                smooth: {
                    type: 'continuous'
                }
            },
            physics: {
                stabilization: false,
                barnesHut: {
                    gravitationalConstant: -80000,
                    springConstant: 0.001,
                    springLength: 200
                }
            },
            layout: {
                hierarchical: {
                    direction: 'UD',
                    sortMethod: 'directed'
                }
            }
        };
        var network = new vis.Network(container, data, options);
        
        function togglePhysics() {
            network.setOptions({
                physics: {
                    enabled: !network.physics.stabilization
                }
            });
        }
        
        // Add event listeners
        network.on("click", function (params) {
            if (params.nodes.length > 0) {
                var nodeId = params.nodes[0];
                var node = nodes.get(nodeId);
                console.log('Clicked on node:', node);
            }
        });
    </script>
</body>
</html>
"""
        
        # Generate nodes data
        nodes_data = []
        for module_name, module_info in self.dependency_graph.modules.items():
            node_data = {
                'id': module_name,
                'label': f'{module_name}\\n{module_info.source}',
                'title': f'Path: {module_info.path}\\nDependencies: {", ".join(module_info.dependencies)}'
            }
            nodes_data.append(node_data)
        
        # Generate edges data
        edges_data = []
        for edge in self.dependency_graph.graph.edges():
            source, target = edge
            edge_data = {
                'from': source,
                'to': target,
                'arrows': 'to'
            }
            edges_data.append(edge_data)
        
        # Highlight circular dependencies
        for cycle in self.dependency_graph.circular_dependencies:
            for i in range(len(cycle)):
                source = cycle[i]
                target = cycle[(i + 1) % len(cycle)]
                edge_data = {
                    'from': source,
                    'to': target,
                    'arrows': 'to',
                    'color': {'color': 'red', 'width': 3}
                }
                edges_data.append(edge_data)
        
        # Replace placeholders in template
        html_content = html_template.replace(
            '{nodes_data}', 
            ',\n            '.join([json.dumps(node) for node in nodes_data])
        ).replace(
            '{edges_data}', 
            ',\n            '.join([json.dumps(edge) for edge in edges_data])
        )
        
        return html_content
    
    def generate_refactoring_suggestions(self) -> List[str]:
        """Generate suggestions for breaking circular dependencies"""
        suggestions = []
        
        for cycle in self.dependency_graph.circular_dependencies:
            suggestions.append(f"Circular dependency detected: {' -> '.join(cycle)}")
            suggestions.append("Suggestions to break the cycle:")
            
            # Analyze the cycle and suggest solutions
            for i, module_name in enumerate(cycle):
                module_info = self.dependency_graph.modules.get(module_name)
                if module_info:
                    suggestions.append(f"  - {module_name}: Consider extracting shared logic to a separate module")
                    suggestions.append(f"    Source: {module_info.source}")
                    suggestions.append(f"    Dependencies: {', '.join(module_info.dependencies)}")
            
            suggestions.append("")
        
        return suggestions
    
    def analyze(self) -> Dict[str, Any]:
        """Run the complete analysis"""
        print("🔍 Finding Terragrunt files...")
        self.terragrunt_files = self.find_terragrunt_files()
        print(f"Found {len(self.terragrunt_files)} Terragrunt files")
        
        print("📖 Parsing Terragrunt configurations...")
        for file_path in self.terragrunt_files:
            module_info = self.parse_terragrunt_file(file_path)
            if module_info:
                self.dependency_graph.modules[module_info.name] = module_info
        
        print("📖 Parsing Terraform files...")
        self.parse_terraform_files()
        
        print("🔗 Building dependency graph...")
        self.build_dependency_graph()
        
        print("🔄 Detecting circular dependencies...")
        cycles = self.detect_circular_dependencies()
        
        # Generate analysis results
        results = {
            'modules': {name: {
                'source': info.source,
                'path': info.path,
                'dependencies': info.dependencies,
                'terragrunt_dependencies': info.terragrunt_dependencies,
                'variables': info.variables,
                'outputs': info.outputs
            } for name, info in self.dependency_graph.modules.items()},
            'circular_dependencies': cycles,
            'total_modules': len(self.dependency_graph.modules),
            'total_dependencies': len(self.dependency_graph.graph.edges()),
            'refactoring_suggestions': self.generate_refactoring_suggestions()
        }
        
        return results


def main():
    parser = argparse.ArgumentParser(description='Terraform Module Dependency Analyzer')
    parser.add_argument('--path', default='.', help='Path to analyze (default: current directory)')
    parser.add_argument('--output', help='Output file path')
    parser.add_argument('--format', choices=['json', 'dot', 'mermaid', 'html'], 
                       default='json', help='Output format')
    
    args = parser.parse_args()
    
    # Initialize analyzer
    analyzer = TerraformDependencyAnalyzer(args.path)
    
    # Run analysis
    results = analyzer.analyze()
    
    # Print summary
    print(f"\n📊 Analysis Summary:")
    print(f"  Total modules: {results['total_modules']}")
    print(f"  Total dependencies: {results['total_dependencies']}")
    print(f"  Circular dependencies: {len(results['circular_dependencies'])}")
    
    if results['circular_dependencies']:
        print(f"\n⚠️  Circular Dependencies Detected:")
        for cycle in results['circular_dependencies']:
            print(f"  {' -> '.join(cycle)}")
    
    # Generate output
    if args.format == 'json':
        output_content = json.dumps(results, indent=2)
    elif args.format == 'dot':
        output_content = analyzer.generate_dot_graph()
    elif args.format == 'mermaid':
        output_content = analyzer.generate_mermaid_diagram()
    elif args.format == 'html':
        output_content = analyzer.generate_html_visualization()
    
    # Write output
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output_content)
        print(f"\n💾 Output written to: {args.output}")
    else:
        print(f"\n📄 Output ({args.format}):")
        print(output_content)


if __name__ == "__main__":
    main() 