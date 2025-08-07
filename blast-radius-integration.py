#!/usr/bin/env python3
"""
Blast Radius Integration for Terragrunt-Olechka

This script integrates Blast Radius functionality to generate interactive
Terraform dependency diagrams for the terragrunt-olechka repository.

Features:
- Generate interactive dependency diagrams
- Serve diagrams via web interface
- Export static diagrams
- Analyze specific environments
- Generate documentation

Usage:
    python blast-radius-integration.py [--serve] [--export] [--env ENV] [--port PORT]
"""

import os
import sys
import json
import argparse
import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Any
import webbrowser
import time
import threading


class BlastRadiusIntegration:
    """Integration class for Blast Radius functionality"""
    
    def __init__(self, root_path: str = "."):
        self.root_path = Path(root_path)
        self.diagrams_dir = self.root_path / "diagrams"
        self.diagrams_dir.mkdir(exist_ok=True)
        
    def check_blast_radius_installed(self) -> bool:
        """Check if Blast Radius is installed"""
        try:
            result = subprocess.run(
                ["blast-radius", "--help"], 
                capture_output=True, 
                text=True, 
                timeout=10
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False
    
    def install_blast_radius(self) -> bool:
        """Install Blast Radius if not already installed"""
        if self.check_blast_radius_installed():
            print("✅ Blast Radius is already installed")
            return True
            
        print("📦 Installing Blast Radius...")
        try:
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "blastradius"],
                check=True
            )
            print("✅ Blast Radius installed successfully")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to install Blast Radius: {e}")
            return False
    
    def find_terragrunt_environments(self) -> List[Path]:
        """Find all terragrunt environments in the repository"""
        environments = []
        
        # Look for directories with terragrunt.hcl files
        for item in self.root_path.iterdir():
            if item.is_dir() and (item / "terragrunt.hcl").exists():
                environments.append(item)
        
        # Also check for environment subdirectories
        for item in self.root_path.iterdir():
            if item.is_dir():
                for subitem in item.iterdir():
                    if subitem.is_dir() and (subitem / "terragrunt.hcl").exists():
                        environments.append(subitem)
        
        return environments
    
    def generate_diagram_for_environment(self, env_path: Path, output_format: str = "html") -> Optional[Path]:
        """Generate a Blast Radius diagram for a specific environment"""
        env_name = env_path.name
        output_file = self.diagrams_dir / f"{env_name}-dependency-diagram.{output_format}"
        
        print(f"🎨 Generating diagram for {env_name}...")
        
        try:
            # Run blast-radius command
            cmd = [
                "blast-radius",
                "--serve", str(env_path),
                "--output", str(output_file)
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0:
                print(f"✅ Diagram generated: {output_file}")
                return output_file
            else:
                print(f"❌ Failed to generate diagram: {result.stderr}")
                return None
                
        except subprocess.TimeoutExpired:
            print(f"❌ Timeout generating diagram for {env_name}")
            return None
        except Exception as e:
            print(f"❌ Error generating diagram: {e}")
            return None
    
    def serve_diagram(self, env_path: Path, port: int = 5000) -> None:
        """Serve a Blast Radius diagram via web interface"""
        env_name = env_path.name
        print(f"🌐 Serving diagram for {env_name} on port {port}...")
        
        try:
            # Start blast-radius server
            cmd = [
                "blast-radius",
                "--serve", str(env_path),
                "--port", str(port)
            ]
            
            print(f"🚀 Starting server at http://localhost:{port}")
            print("💡 Press Ctrl+C to stop the server")
            
            # Open browser after a short delay
            def open_browser():
                time.sleep(2)
                webbrowser.open(f"http://localhost:{port}")
            
            threading.Thread(target=open_browser, daemon=True).start()
            
            # Run the server
            subprocess.run(cmd)
            
        except KeyboardInterrupt:
            print("\n🛑 Server stopped")
        except Exception as e:
            print(f"❌ Error serving diagram: {e}")
    
    def generate_all_diagrams(self, output_format: str = "html") -> Dict[str, Path]:
        """Generate diagrams for all environments"""
        environments = self.find_terragrunt_environments()
        results = {}
        
        print(f"🔍 Found {len(environments)} environments:")
        for env in environments:
            print(f"  - {env.name}")
        
        for env_path in environments:
            output_file = self.generate_diagram_for_environment(env_path, output_format)
            if output_file:
                results[env_path.name] = output_file
        
        return results
    
    def create_diagram_index(self, diagrams: Dict[str, Path]) -> Path:
        """Create an index HTML file for all generated diagrams"""
        index_file = self.diagrams_dir / "index.html"
        
        html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terragrunt-Olechka - Blast Radius Diagrams</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            border-radius: 10px;
            margin-bottom: 30px;
            text-align: center;
        }}
        .header h1 {{
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }}
        .header p {{
            margin: 10px 0 0 0;
            opacity: 0.9;
            font-size: 1.1em;
        }}
        .diagrams-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }}
        .diagram-card {{
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }}
        .diagram-card:hover {{
            transform: translateY(-2px);
            box-shadow: 0 8px 15px rgba(0, 0, 0, 0.15);
        }}
        .diagram-card h3 {{
            margin: 0 0 10px 0;
            color: #333;
            font-size: 1.3em;
        }}
        .diagram-card p {{
            margin: 0 0 15px 0;
            color: #666;
            line-height: 1.5;
        }}
        .diagram-card a {{
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            padding: 10px 20px;
            border-radius: 5px;
            font-weight: 500;
            transition: opacity 0.2s ease;
        }}
        .diagram-card a:hover {{
            opacity: 0.9;
        }}
        .info-box {{
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 15px;
            margin: 20px 0;
            border-radius: 0 5px 5px 0;
        }}
        .info-box h4 {{
            margin: 0 0 10px 0;
            color: #1976d2;
        }}
        .info-box p {{
            margin: 0;
            color: #424242;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Terragrunt-Olechka</h1>
        <p>Interactive Terraform Dependency Diagrams</p>
    </div>
    
    <div class="info-box">
        <h4>📊 About These Diagrams</h4>
        <p>These interactive diagrams were generated using <a href="https://github.com/28mm/blast-radius" target="_blank">Blast Radius</a>, 
        a tool for visualizing Terraform dependency graphs. Click on any diagram to explore the infrastructure dependencies interactively.</p>
    </div>
    
    <div class="diagrams-grid">
"""
        
        for env_name, diagram_path in diagrams.items():
            relative_path = diagram_path.relative_to(self.diagrams_dir)
            html_content += f"""
        <div class="diagram-card">
            <h3>🌍 {env_name.title()} Environment</h3>
            <p>Interactive dependency diagram for the {env_name} environment infrastructure.</p>
            <a href="{relative_path}" target="_blank">View Diagram</a>
        </div>
"""
        
        html_content += """
    </div>
    
    <div class="info-box">
        <h4>🔧 How to Use</h4>
        <p>• <strong>Zoom:</strong> Use mouse wheel or pinch gestures<br>
        • <strong>Pan:</strong> Click and drag to move around<br>
        • <strong>Search:</strong> Use the search box to find specific resources<br>
        • <strong>Filter:</strong> Click on nodes to highlight dependencies</p>
    </div>
</body>
</html>
"""
        
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"✅ Index file created: {index_file}")
        return index_file
    
    def create_documentation(self) -> Path:
        """Create documentation for the Blast Radius integration"""
        doc_file = self.diagrams_dir / "README.md"
        
        doc_content = """# Blast Radius Integration Documentation

This directory contains interactive Terraform dependency diagrams generated using [Blast Radius](https://github.com/28mm/blast-radius).

## What is Blast Radius?

Blast Radius is a tool for reasoning about Terraform dependency graphs with interactive visualizations. It helps you:

- **Learn** about Terraform or one of its providers through real examples
- **Document** your infrastructure
- **Reason** about relationships between resources and evaluate changes to them
- **Interact** with dependency diagrams in your browser

## Generated Diagrams

The diagrams in this directory show the dependency relationships between different Terraform modules and resources in the terragrunt-olechka infrastructure.

### Available Diagrams

- **Environment-specific diagrams**: Each environment (dev, staging, prod) has its own diagram
- **Interactive features**: Zoom, pan, search, and filter capabilities
- **Resource relationships**: Visual representation of how resources depend on each other

## How to Use

### Viewing Diagrams

1. Open `index.html` in your web browser to see all available diagrams
2. Click on any diagram to open it in a new tab
3. Use the interactive features to explore the infrastructure

### Interactive Features

- **Zoom**: Use mouse wheel or pinch gestures to zoom in/out
- **Pan**: Click and drag to move around the diagram
- **Search**: Use the search box to find specific resources
- **Filter**: Click on nodes to highlight their dependencies
- **Details**: Hover over nodes to see additional information

### Generating New Diagrams

To generate new diagrams, use the `blast-radius-integration.py` script:

```bash
# Generate diagrams for all environments
python blast-radius-integration.py --export

# Serve a specific environment diagram
python blast-radius-integration.py --serve --env eu-west-1

# Generate diagrams in different formats
python blast-radius-integration.py --export --format svg
```

## Prerequisites

- Python 3.7 or newer
- Graphviz (for generating static diagrams)
- Blast Radius (installed via pip)

### Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Install Graphviz (macOS)
brew install graphviz

# Install Graphviz (Ubuntu/Debian)
sudo apt-get install graphviz

# Install Graphviz (Windows)
# Download from https://graphviz.org/download/
```

## Troubleshooting

### Common Issues

1. **Blast Radius not found**: Run `pip install blastradius`
2. **Graphviz not found**: Install Graphviz using your package manager
3. **Permission errors**: Ensure you have write permissions to the diagrams directory
4. **Port conflicts**: Use a different port with `--port` option

### Getting Help

- [Blast Radius Documentation](https://github.com/28mm/blast-radius)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)

## File Structure

```
diagrams/
├── index.html              # Main index page
├── README.md               # This documentation
├── eu-west-1-diagram.html  # eu-west-1 environment diagram
├── dev-diagram.html        # Development environment diagram
├── staging-diagram.html    # Staging environment diagram
└── prod-diagram.html       # Production environment diagram
```

## Contributing

When adding new environments or modules to the infrastructure:

1. Update the terragrunt configuration
2. Run the diagram generation script
3. Update this documentation if needed
4. Commit the new diagrams to version control

---

*Generated by Blast Radius Integration for Terragrunt-Olechka*
"""
        
        with open(doc_file, 'w', encoding='utf-8') as f:
            f.write(doc_content)
        
        print(f"✅ Documentation created: {doc_file}")
        return doc_file


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description="Blast Radius Integration for Terragrunt-Olechka",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python blast-radius-integration.py --export                    # Generate all diagrams
  python blast-radius-integration.py --serve --env eu-west-1     # Serve specific environment
  python blast-radius-integration.py --export --format svg       # Generate SVG diagrams
  python blast-radius-integration.py --serve --port 8080         # Serve on custom port
        """
    )
    
    parser.add_argument(
        "--serve", 
        action="store_true",
        help="Serve diagrams via web interface"
    )
    
    parser.add_argument(
        "--export", 
        action="store_true",
        help="Export diagrams to files"
    )
    
    parser.add_argument(
        "--env", 
        type=str,
        help="Specific environment to analyze (e.g., eu-west-1, dev, staging, prod)"
    )
    
    parser.add_argument(
        "--port", 
        type=int,
        default=5000,
        help="Port for web server (default: 5000)"
    )
    
    parser.add_argument(
        "--format", 
        type=str,
        default="html",
        choices=["html", "svg", "png"],
        help="Output format for exported diagrams (default: html)"
    )
    
    parser.add_argument(
        "--path", 
        type=str,
        default=".",
        help="Root path for analysis (default: current directory)"
    )
    
    args = parser.parse_args()
    
    # Initialize integration
    integration = BlastRadiusIntegration(args.path)
    
    # Check/install Blast Radius
    if not integration.install_blast_radius():
        print("❌ Failed to install Blast Radius. Please install manually:")
        print("   pip install blastradius")
        sys.exit(1)
    
    # Find environments
    environments = integration.find_terragrunt_environments()
    
    if not environments:
        print("❌ No terragrunt environments found")
        sys.exit(1)
    
    print(f"🔍 Found {len(environments)} environments:")
    for env in environments:
        print(f"  - {env.name}")
    
    # Handle specific environment
    if args.env:
        target_env = None
        for env in environments:
            if env.name == args.env:
                target_env = env
                break
        
        if not target_env:
            print(f"❌ Environment '{args.env}' not found")
            sys.exit(1)
        
        if args.serve:
            integration.serve_diagram(target_env, args.port)
        elif args.export:
            integration.generate_diagram_for_environment(target_env, args.format)
        else:
            print("❌ Please specify --serve or --export")
            sys.exit(1)
    
    # Handle all environments
    else:
        if args.export:
            diagrams = integration.generate_all_diagrams(args.format)
            if diagrams:
                integration.create_diagram_index(diagrams)
                integration.create_documentation()
                print(f"✅ Generated {len(diagrams)} diagrams")
            else:
                print("❌ No diagrams were generated")
        elif args.serve:
            print("❌ Please specify an environment with --env when using --serve")
            sys.exit(1)
        else:
            print("❌ Please specify --serve or --export")
            sys.exit(1)


if __name__ == "__main__":
    main() 