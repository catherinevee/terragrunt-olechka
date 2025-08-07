#!/usr/bin/env python3
"""
Test script for the Terraform Dependency Analyzer

This script demonstrates how to use the analyzer with the terragrunt-olechka structure.
"""

import sys
import os
from pathlib import Path

# Add the current directory to Python path to import the analyzer
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from terraform_dependency_analyzer import TerraformDependencyAnalyzer

def test_analyzer():
    """Test the analyzer with the terragrunt-olechka structure"""
    
    print("🧪 Testing Terraform Dependency Analyzer")
    print("=" * 50)
    
    # Initialize analyzer with the current directory
    analyzer = TerraformDependencyAnalyzer(".")
    
    # Run analysis
    results = analyzer.analyze()
    
    # Print detailed results
    print(f"\n📊 Analysis Results:")
    print(f"  Total modules found: {results['total_modules']}")
    print(f"  Total dependencies: {results['total_dependencies']}")
    print(f"  Circular dependencies: {len(results['circular_dependencies'])}")
    
    # Print module details
    print(f"\n📦 Modules Found:")
    for module_name, module_info in results['modules'].items():
        print(f"  {module_name}:")
        print(f"    Source: {module_info['source']}")
        print(f"    Path: {module_info['path']}")
        print(f"    Dependencies: {module_info['dependencies']}")
        print(f"    Terragrunt Dependencies: {module_info['terragrunt_dependencies']}")
        print(f"    Outputs: {module_info['outputs']}")
        print()
    
    # Print circular dependencies
    if results['circular_dependencies']:
        print(f"⚠️  Circular Dependencies Detected:")
        for i, cycle in enumerate(results['circular_dependencies'], 1):
            print(f"  Cycle {i}: {' -> '.join(cycle)}")
        print()
    
    # Print refactoring suggestions
    if results['refactoring_suggestions']:
        print(f"💡 Refactoring Suggestions:")
        for suggestion in results['refactoring_suggestions']:
            print(f"  {suggestion}")
        print()
    
    # Generate visualizations
    print("🎨 Generating Visualizations...")
    
    # Generate DOT graph
    dot_content = analyzer.generate_dot_graph()
    with open("dependency-graph.dot", "w") as f:
        f.write(dot_content)
    print("  ✅ DOT graph saved to: dependency-graph.dot")
    
    # Generate Mermaid diagram
    mermaid_content = analyzer.generate_mermaid_diagram()
    with open("dependency-graph.md", "w") as f:
        f.write("# Terraform Module Dependencies\n\n")
        f.write("```mermaid\n")
        f.write(mermaid_content)
        f.write("\n```\n")
    print("  ✅ Mermaid diagram saved to: dependency-graph.md")
    
    # Generate HTML visualization
    html_content = analyzer.generate_html_visualization()
    with open("dependency-graph.html", "w") as f:
        f.write(html_content)
    print("  ✅ HTML visualization saved to: dependency-graph.html")
    
    print(f"\n🎉 Analysis complete! Check the generated files for visualizations.")

def test_specific_path():
    """Test the analyzer with a specific path"""
    
    print("\n🧪 Testing with specific path: eu-west-1")
    print("=" * 50)
    
    # Test with eu-west-1 directory
    eu_west_1_path = Path("eu-west-1")
    if eu_west_1_path.exists():
        analyzer = TerraformDependencyAnalyzer("eu-west-1")
        results = analyzer.analyze()
        
        print(f"📊 eu-west-1 Analysis:")
        print(f"  Modules: {results['total_modules']}")
        print(f"  Dependencies: {results['total_dependencies']}")
        print(f"  Circular: {len(results['circular_dependencies'])}")
        
        # Generate eu-west-1 specific visualizations
        dot_content = analyzer.generate_dot_graph()
        with open("eu-west-1-dependency-graph.dot", "w") as f:
            f.write(dot_content)
        print("  ✅ eu-west-1 DOT graph saved")
        
    else:
        print("  ⚠️  eu-west-1 directory not found")

if __name__ == "__main__":
    # Test the analyzer
    test_analyzer()
    
    # Test with specific path
    test_specific_path()
    
    print(f"\n📝 Next steps:")
    print(f"  1. Install Graphviz to generate PNG from DOT files:")
    print(f"     dot -Tpng dependency-graph.dot -o dependency-graph.png")
    print(f"  2. Open dependency-graph.html in a web browser for interactive visualization")
    print(f"  3. View dependency-graph.md for Mermaid diagram")
    print(f"  4. Use the analyzer with different paths: python terraform-dependency-analyzer.py --path ./path/to/analyze") 