#!/usr/bin/env python3
"""
Enhanced Terraform Module Dependency Analyzer

This enhanced version includes:
1. Data source dependency analysis
2. Remote state reference detection
3. Local file references
4. Variable interpolation analysis
5. More sophisticated circular dependency detection
6. Dependency path analysis
7. Impact analysis for changes
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional, Any, NamedTuple
from collections import defaultdict, deque
import hcl2
import networkx as nx
from dataclasses import dataclass, field
import re
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class DependencyInfo:
    """Detailed information about a dependency"""
    source_module: str
    target_module: str
    dependency_type: str  # 'module', 'data', 'remote_state', 'local_file'
    reference_path: str
    line_number: Optional[int] = None
    file_path: Optional[str] = None


@dataclass
class ModuleInfo:
    """Enhanced module information"""
    name: str
    source: str
    path: str
    variables: Dict[str, Any] = field(default_factory=dict)
    outputs: List[str] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    terragrunt_dependencies: List[str] = field(default_factory=list)
    data_sources: List[str] = field(default_factory=list)
    resources: List[str] = field(default_factory=list)
    dependency_details: List[DependencyInfo] = field(default_factory=list)
    complexity_score: int = 0


@dataclass
class DependencyGraph:
    """Enhanced dependency graph"""
    modules: Dict[str, ModuleInfo] = field(default_factory=dict)
    graph: nx.DiGraph = field(default_factory=lambda: nx.DiGraph())
    circular_dependencies: List[List[str]] = field(default_factory=list)
    dependency_paths: Dict[str, List[List[str]]] = field(default_factory=dict)
    impact_analysis: Dict[str, Set[str]] = field(default_factory=dict)


class EnhancedTerraformDependencyAnalyzer:
    """Enhanced analyzer with advanced dependency detection"""
    
    def __init__(self, root_path: str, verbose: bool = False):
        self.root_path = Path(root_path)
        self.dependency_graph = DependencyGraph()
        self.terragrunt_files = []
        self.terraform_files = []
        self.verbose = verbose
        
        if verbose:
            logging.getLogger().setLevel(logging.DEBUG)
    
    def find_configuration_files(self) -> Tuple[List[Path], List[Path]]:
        """Find all Terraform and Terragrunt configuration files"""
        terragrunt_files = []
        terraform_files = []
        
        for file_path in self.root_path.rglob("*"):
            if file_path.is_file():
                if file_path.name == "terragrunt.hcl":
                    terragrunt_files.append(file_path)
                elif file_path.suffix == ".tf":
                    terraform_files.append(file_path)
        
        return terragrunt_files, terraform_files
    
    def parse_terragrunt_file(self, file_path: Path) -> Optional[ModuleInfo]:
        """Parse terragrunt.hcl file with enhanced dependency detection"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
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
            
            # Extract dependencies with detailed information
            if 'dependency' in parsed:
                for dep in parsed['dependency']:
                    for dep_name, dep_config in dep.items():
                        if 'config_path' in dep_config:
                            config_path = dep_config['config_path']
                            if config_path.startswith('../../'):
                                parts = config_path.split('/')
                                if len(parts) >= 2:
                                    module_name = parts[-1]
                                    module_info.terragrunt_dependencies.append(module_name)
                                    
                                    # Add detailed dependency info
                                    dep_info = DependencyInfo(
                                        source_module=module_info.name,
                                        target_module=module_name,
                                        dependency_type='terragrunt',
                                        reference_path=config_path,
                                        file_path=str(file_path)
                                    )
                                    module_info.dependency_details.append(dep_info)
            
            # Extract inputs and analyze for variable dependencies
            if 'inputs' in parsed:
                module_info.variables = parsed['inputs']
                self._analyze_variable_dependencies(module_info, parsed['inputs'], str(file_path))
            
            # Calculate complexity score
            module_info.complexity_score = self._calculate_complexity_score(module_info)
            
            return module_info
            
        except Exception as e:
            logger.error(f"Error parsing {file_path}: {e}")
            return None
    
    def parse_terraform_files(self) -> None:
        """Parse Terraform files with enhanced analysis"""
        for file_path in self.terraform_files:
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
                            
                            # Extract variables and analyze dependencies
                            if 'variables' in module_config:
                                module_info.variables = module_config['variables']
                                self._analyze_variable_dependencies(module_info, module_config['variables'], str(file_path))
                            
                            # Extract dependencies from module configuration
                            self._extract_module_dependencies(module_info, module_config, str(file_path))
                            
                            self.dependency_graph.modules[module_name] = module_info
                
                # Extract data sources
                if 'data' in parsed:
                    for data_block in parsed['data']:
                        for data_name, data_config in data_block.items():
                            self._analyze_data_source_dependencies(data_name, data_config, str(file_path))
                
                # Extract outputs
                if 'output' in parsed:
                    for output_block in parsed['output']:
                        for output_name, output_config in output_block.items():
                            if 'value' in output_config:
                                self._analyze_output_dependencies(output_config['value'], str(file_path))
                
                # Extract resources
                if 'resource' in parsed:
                    for resource_block in parsed['resource']:
                        for resource_type, resource_config in resource_block.items():
                            self._analyze_resource_dependencies(resource_type, resource_config, str(file_path))
                
            except Exception as e:
                logger.error(f"Error parsing {file_path}: {e}")
    
    def _analyze_variable_dependencies(self, module_info: ModuleInfo, variables: Dict, file_path: str) -> None:
        """Analyze variable dependencies with detailed tracking"""
        variables_str = str(variables)
        
        # Look for module references
        module_refs = re.findall(r'module\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)', variables_str)
        for ref_module, ref_output in module_refs:
            if ref_module != module_info.name:
                module_info.dependencies.append(ref_module)
                
                dep_info = DependencyInfo(
                    source_module=module_info.name,
                    target_module=ref_module,
                    dependency_type='module_output',
                    reference_path=f'module.{ref_module}.{ref_output}',
                    file_path=file_path
                )
                module_info.dependency_details.append(dep_info)
        
        # Look for data source references
        data_refs = re.findall(r'data\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)', variables_str)
        for data_type, data_name, data_output in data_refs:
            module_info.data_sources.append(f"{data_type}.{data_name}")
            
            dep_info = DependencyInfo(
                source_module=module_info.name,
                target_module=f"{data_type}.{data_name}",
                dependency_type='data_source',
                reference_path=f'data.{data_type}.{data_name}.{data_output}',
                file_path=file_path
            )
            module_info.dependency_details.append(dep_info)
        
        # Look for remote state references
        remote_state_refs = re.findall(r'data\.terraform_remote_state\.([a-zA-Z0-9_-]+)\.outputs\.([a-zA-Z0-9_-]+)', variables_str)
        for remote_state_name, remote_output in remote_state_refs:
            dep_info = DependencyInfo(
                source_module=module_info.name,
                target_module=f"remote_state.{remote_state_name}",
                dependency_type='remote_state',
                reference_path=f'data.terraform_remote_state.{remote_state_name}.outputs.{remote_output}',
                file_path=file_path
            )
            module_info.dependency_details.append(dep_info)
    
    def _extract_module_dependencies(self, module_info: ModuleInfo, module_config: Dict, file_path: str) -> None:
        """Extract dependencies from module configuration"""
        config_str = str(module_config)
        
        # Look for module references
        module_refs = re.findall(r'module\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)', config_str)
        for ref_module, ref_output in module_refs:
            if ref_module != module_info.name:
                module_info.dependencies.append(ref_module)
                
                dep_info = DependencyInfo(
                    source_module=module_info.name,
                    target_module=ref_module,
                    dependency_type='module_reference',
                    reference_path=f'module.{ref_module}.{ref_output}',
                    file_path=file_path
                )
                module_info.dependency_details.append(dep_info)
    
    def _analyze_data_source_dependencies(self, data_name: str, data_config: Dict, file_path: str) -> None:
        """Analyze data source dependencies"""
        config_str = str(data_config)
        
        # Look for references to other modules or resources
        module_refs = re.findall(r'module\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)', config_str)
        for ref_module, ref_output in module_refs:
            if ref_module in self.dependency_graph.modules:
                dep_info = DependencyInfo(
                    source_module=f"data.{data_name}",
                    target_module=ref_module,
                    dependency_type='data_source_module',
                    reference_path=f'module.{ref_module}.{ref_output}',
                    file_path=file_path
                )
                self.dependency_graph.modules[ref_module].dependency_details.append(dep_info)
    
    def _analyze_output_dependencies(self, output_value: Any, file_path: str) -> None:
        """Analyze output dependencies"""
        value_str = str(output_value)
        
        # Look for module references in outputs
        module_refs = re.findall(r'module\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)', value_str)
        for ref_module, ref_output in module_refs:
            if ref_module in self.dependency_graph.modules:
                if ref_output not in self.dependency_graph.modules[ref_module].outputs:
                    self.dependency_graph.modules[ref_module].outputs.append(ref_output)
    
    def _analyze_resource_dependencies(self, resource_type: str, resource_config: Dict, file_path: str) -> None:
        """Analyze resource dependencies"""
        config_str = str(resource_config)
        
        # Look for module references in resources
        module_refs = re.findall(r'module\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)', config_str)
        for ref_module, ref_output in module_refs:
            if ref_module in self.dependency_graph.modules:
                dep_info = DependencyInfo(
                    source_module=f"resource.{resource_type}",
                    target_module=ref_module,
                    dependency_type='resource_module',
                    reference_path=f'module.{ref_module}.{ref_output}',
                    file_path=file_path
                )
                self.dependency_graph.modules[ref_module].dependency_details.append(dep_info)
    
    def _calculate_complexity_score(self, module_info: ModuleInfo) -> int:
        """Calculate complexity score for a module"""
        score = 0
        
        # Base score
        score += 1
        
        # Add points for dependencies
        score += len(module_info.dependencies) * 2
        score += len(module_info.terragrunt_dependencies) * 2
        
        # Add points for variables
        score += len(module_info.variables)
        
        # Add points for outputs
        score += len(module_info.outputs)
        
        # Add points for data sources
        score += len(module_info.data_sources) * 3
        
        # Add points for resources
        score += len(module_info.resources) * 2
        
        return score
    
    def build_dependency_graph(self) -> None:
        """Build enhanced dependency graph"""
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
        """Detect circular dependencies with enhanced analysis"""
        try:
            cycles = list(nx.simple_cycles(self.dependency_graph.graph))
            self.dependency_graph.circular_dependencies = cycles
            return cycles
        except nx.NetworkXNoCycle:
            return []
    
    def analyze_dependency_paths(self) -> Dict[str, List[List[str]]]:
        """Analyze all dependency paths between modules"""
        paths = {}
        
        for source in self.dependency_graph.modules:
            for target in self.dependency_graph.modules:
                if source != target:
                    try:
                        all_paths = list(nx.all_simple_paths(self.dependency_graph.graph, source, target))
                        if all_paths:
                            paths[f"{source}->{target}"] = all_paths
                    except nx.NetworkXNoPath:
                        continue
        
        self.dependency_graph.dependency_paths = paths
        return paths
    
    def analyze_impact(self, module_name: str) -> Set[str]:
        """Analyze the impact of changes to a specific module"""
        if module_name not in self.dependency_graph.modules:
            return set()
        
        # Find all modules that depend on this module (directly or indirectly)
        impact_set = set()
        
        for module in self.dependency_graph.modules:
            if module != module_name:
                try:
                    # Check if there's a path from module_name to this module
                    if nx.has_path(self.dependency_graph.graph, module_name, module):
                        impact_set.add(module)
                except nx.NetworkXNoPath:
                    continue
        
        self.dependency_graph.impact_analysis[module_name] = impact_set
        return impact_set
    
    def generate_enhanced_dot_graph(self) -> str:
        """Generate enhanced DOT graph with more details"""
        dot_content = ["digraph G {"]
        dot_content.append("  rankdir=TB;")
        dot_content.append("  node [shape=box, style=filled];")
        dot_content.append("  edge [color=gray];")
        
        # Add nodes with complexity-based styling
        for module_name, module_info in self.dependency_graph.modules.items():
            # Color based on complexity
            if module_info.complexity_score > 10:
                fillcolor = "lightcoral"
            elif module_info.complexity_score > 5:
                fillcolor = "lightyellow"
            else:
                fillcolor = "lightblue"
            
            # Add node with detailed label
            label = f"{module_name}\\n{module_info.source}\\nComplexity: {module_info.complexity_score}"
            dot_content.append(f'  "{module_name}" [label="{label}", fillcolor="{fillcolor}"];')
        
        # Add edges with dependency type information
        for module_name, module_info in self.dependency_graph.modules.items():
            for dep_info in module_info.dependency_details:
                if dep_info.target_module in self.dependency_graph.modules:
                    edge_style = self._get_edge_style(dep_info.dependency_type)
                    dot_content.append(f'  "{dep_info.target_module}" -> "{module_name}" {edge_style};')
        
        # Highlight circular dependencies
        if self.dependency_graph.circular_dependencies:
            dot_content.append("  edge [color=red, penwidth=3];")
            for cycle in self.dependency_graph.circular_dependencies:
                for i in range(len(cycle)):
                    source = cycle[i]
                    target = cycle[(i + 1) % len(cycle)]
                    dot_content.append(f'  "{source}" -> "{target}" [color=red, penwidth=3];')
        
        dot_content.append("}")
        return "\n".join(dot_content)
    
    def _get_edge_style(self, dependency_type: str) -> str:
        """Get edge styling based on dependency type"""
        styles = {
            'module_output': '[color=blue, style=solid]',
            'terragrunt': '[color=green, style=solid]',
            'data_source': '[color=orange, style=dashed]',
            'remote_state': '[color=purple, style=dotted]',
            'module_reference': '[color=blue, style=solid]',
            'data_source_module': '[color=orange, style=dashed]',
            'resource_module': '[color=brown, style=solid]'
        }
        return styles.get(dependency_type, '[color=gray, style=solid]')
    
    def generate_enhanced_mermaid_diagram(self) -> str:
        """Generate enhanced Mermaid diagram"""
        mermaid_content = ["graph TD"]
        
        # Add nodes with styling
        for module_name, module_info in self.dependency_graph.modules.items():
            # Style based on complexity
            if module_info.complexity_score > 10:
                style = ":::complex"
            elif module_info.complexity_score > 5:
                style = ":::medium"
            else:
                style = ":::simple"
            
            mermaid_content.append(f'    {module_name}["{module_name}<br/>{module_info.source}<br/>Complexity: {module_info.complexity_score}"]{style}')
        
        # Add edges with dependency types
        for module_name, module_info in self.dependency_graph.modules.items():
            for dep_info in module_info.dependency_details:
                if dep_info.target_module in self.dependency_graph.modules:
                    edge_style = self._get_mermaid_edge_style(dep_info.dependency_type)
                    mermaid_content.append(f'    {dep_info.target_module} {edge_style} {module_name}')
        
        # Add styling classes
        mermaid_content.extend([
            "    classDef simple fill:#e1f5fe",
            "    classDef medium fill:#fff3e0",
            "    classDef complex fill:#ffebee"
        ])
        
        # Add circular dependency warnings
        if self.dependency_graph.circular_dependencies:
            mermaid_content.append("    %% Circular Dependencies Detected!")
            for cycle in self.dependency_graph.circular_dependencies:
                cycle_str = " -> ".join(cycle)
                mermaid_content.append(f'    %% Cycle: {cycle_str}')
        
        return "\n".join(mermaid_content)
    
    def _get_mermaid_edge_style(self, dependency_type: str) -> str:
        """Get Mermaid edge styling based on dependency type"""
        styles = {
            'module_output': '-->',
            'terragrunt': '==>',
            'data_source': '-.->',
            'remote_state': '~~~>',
            'module_reference': '-->',
            'data_source_module': '-.->',
            'resource_module': '-->'
        }
        return styles.get(dependency_type, '-->')
    
    def generate_impact_report(self) -> Dict[str, Any]:
        """Generate impact analysis report"""
        impact_report = {
            'high_impact_modules': [],
            'module_impact_analysis': {},
            'recommendations': []
        }
        
        # Analyze impact for all modules
        for module_name in self.dependency_graph.modules:
            impact_set = self.analyze_impact(module_name)
            impact_report['module_impact_analysis'][module_name] = {
                'affected_modules': list(impact_set),
                'impact_count': len(impact_set)
            }
            
            # Identify high-impact modules
            if len(impact_set) > 3:
                impact_report['high_impact_modules'].append({
                    'module': module_name,
                    'impact_count': len(impact_set),
                    'affected_modules': list(impact_set)
                })
        
        # Generate recommendations
        for module_info in impact_report['high_impact_modules']:
            impact_report['recommendations'].append(
                f"Module '{module_info['module']}' has high impact ({module_info['impact_count']} affected modules). "
                f"Consider breaking it into smaller modules or using data sources to reduce coupling."
            )
        
        return impact_report
    
    def analyze(self) -> Dict[str, Any]:
        """Run the complete enhanced analysis"""
        logger.info("🔍 Finding configuration files...")
        self.terragrunt_files, self.terraform_files = self.find_configuration_files()
        logger.info(f"Found {len(self.terragrunt_files)} Terragrunt files and {len(self.terraform_files)} Terraform files")
        
        logger.info("📖 Parsing Terragrunt configurations...")
        for file_path in self.terragrunt_files:
            module_info = self.parse_terragrunt_file(file_path)
            if module_info:
                self.dependency_graph.modules[module_info.name] = module_info
        
        logger.info("📖 Parsing Terraform files...")
        self.parse_terraform_files()
        
        logger.info("🔗 Building dependency graph...")
        self.build_dependency_graph()
        
        logger.info("🔄 Detecting circular dependencies...")
        cycles = self.detect_circular_dependencies()
        
        logger.info("🛤️ Analyzing dependency paths...")
        paths = self.analyze_dependency_paths()
        
        logger.info("📊 Generating impact analysis...")
        impact_report = self.generate_impact_report()
        
        # Generate analysis results
        results = {
            'modules': {name: {
                'source': info.source,
                'path': info.path,
                'dependencies': info.dependencies,
                'terragrunt_dependencies': info.terragrunt_dependencies,
                'variables': info.variables,
                'outputs': info.outputs,
                'data_sources': info.data_sources,
                'resources': info.resources,
                'complexity_score': info.complexity_score,
                'dependency_details': [
                    {
                        'target_module': dep.target_module,
                        'dependency_type': dep.dependency_type,
                        'reference_path': dep.reference_path,
                        'file_path': dep.file_path
                    } for dep in info.dependency_details
                ]
            } for name, info in self.dependency_graph.modules.items()},
            'circular_dependencies': cycles,
            'dependency_paths': paths,
            'impact_analysis': impact_report,
            'total_modules': len(self.dependency_graph.modules),
            'total_dependencies': len(self.dependency_graph.graph.edges()),
            'complexity_analysis': {
                'high_complexity': [name for name, info in self.dependency_graph.modules.items() if info.complexity_score > 10],
                'medium_complexity': [name for name, info in self.dependency_graph.modules.items() if 5 < info.complexity_score <= 10],
                'low_complexity': [name for name, info in self.dependency_graph.modules.items() if info.complexity_score <= 5]
            }
        }
        
        return results


def main():
    parser = argparse.ArgumentParser(description='Enhanced Terraform Module Dependency Analyzer')
    parser.add_argument('--path', default='.', help='Path to analyze (default: current directory)')
    parser.add_argument('--output', help='Output file path')
    parser.add_argument('--format', choices=['json', 'dot', 'mermaid', 'html'], 
                       default='json', help='Output format')
    parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose logging')
    parser.add_argument('--impact', help='Analyze impact of changes to specific module')
    
    args = parser.parse_args()
    
    # Initialize analyzer
    analyzer = EnhancedTerraformDependencyAnalyzer(args.path, args.verbose)
    
    # Run analysis
    results = analyzer.analyze()
    
    # Print summary
    print(f"\n📊 Enhanced Analysis Summary:")
    print(f"  Total modules: {results['total_modules']}")
    print(f"  Total dependencies: {results['total_dependencies']}")
    print(f"  Circular dependencies: {len(results['circular_dependencies'])}")
    print(f"  High complexity modules: {len(results['complexity_analysis']['high_complexity'])}")
    print(f"  Medium complexity modules: {len(results['complexity_analysis']['medium_complexity'])}")
    print(f"  Low complexity modules: {len(results['complexity_analysis']['low_complexity'])}")
    
    if results['circular_dependencies']:
        print(f"\n⚠️  Circular Dependencies Detected:")
        for cycle in results['circular_dependencies']:
            print(f"  {' -> '.join(cycle)}")
    
    if results['impact_analysis']['high_impact_modules']:
        print(f"\n🚨 High Impact Modules:")
        for module_info in results['impact_analysis']['high_impact_modules']:
            print(f"  {module_info['module']}: affects {module_info['impact_count']} modules")
    
    # Analyze specific module impact if requested
    if args.impact:
        impact_set = analyzer.analyze_impact(args.impact)
        print(f"\n📈 Impact Analysis for '{args.impact}':")
        print(f"  Affects {len(impact_set)} modules: {', '.join(impact_set)}")
    
    # Generate output
    if args.format == 'json':
        output_content = json.dumps(results, indent=2)
    elif args.format == 'dot':
        output_content = analyzer.generate_enhanced_dot_graph()
    elif args.format == 'mermaid':
        output_content = analyzer.generate_enhanced_mermaid_diagram()
    elif args.format == 'html':
        # Use the basic HTML generator for now
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