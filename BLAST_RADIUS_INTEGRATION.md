# Blast Radius Integration for Terragrunt-Olechka

This document describes the integration of [Blast Radius](https://github.com/28mm/blast-radius) into the terragrunt-olechka repository to provide interactive Terraform dependency diagrams.

## What is Blast Radius?

Blast Radius is a powerful tool for visualizing Terraform dependency graphs with interactive features. It helps you:

- **Understand Infrastructure**: Visualize how your Terraform resources depend on each other
- **Document Architecture**: Create interactive diagrams for your infrastructure
- **Plan Changes**: See the impact of changes before applying them
- **Debug Issues**: Identify dependency problems and circular references
- **Onboard Team Members**: Help new team members understand the infrastructure

## Features

### Interactive Visualizations
- **Zoom and Pan**: Navigate large dependency graphs easily
- **Search**: Find specific resources quickly
- **Filter**: Highlight dependencies by clicking on nodes
- **Details**: Hover over nodes to see additional information
- **Responsive**: Works on desktop and mobile devices

### Multiple Output Formats
- **HTML**: Interactive web-based diagrams
- **SVG**: Scalable vector graphics for documentation
- **PNG**: Static images for reports and presentations

### Environment Support
- **eu-west-1**: Main production environment
- **dev**: Development environment
- **staging**: Staging environment
- **prod**: Production environment

## Quick Start

### Prerequisites

1. **Python 3.7+**: Required for running the integration scripts
2. **Graphviz**: For generating static diagrams (optional)
3. **Docker**: For running Blast Radius in containers (optional)

### Installation

#### Option 1: Local Installation

```bash
# Install Python dependencies
pip install -r requirements.txt

# Install Graphviz (macOS)
brew install graphviz

# Install Graphviz (Ubuntu/Debian)
sudo apt-get install graphviz

# Install Graphviz (Windows)
# Download from https://graphviz.org/download/
```

#### Option 2: Docker Installation

```bash
# No additional installation required - uses Docker containers
docker --version
docker-compose --version
```

### Basic Usage

#### Generate All Diagrams

```bash
# Using Make
make blast-export

# Using Python script directly
python blast-radius-integration.py --export
```

#### Serve Interactive Diagrams

```bash
# Using Make (interactive)
make blast-serve

# Using Python script directly
python blast-radius-integration.py --serve --env eu-west-1
```

#### Using Docker

```bash
# Start all environments
make blast-docker-all

# Start specific environment
make blast-docker

# Stop all containers
make blast-docker-stop
```

## Detailed Usage

### Command Line Options

The `blast-radius-integration.py` script supports the following options:

```bash
python blast-radius-integration.py [OPTIONS]

Options:
  --serve              Serve diagrams via web interface
  --export             Export diagrams to files
  --env ENV            Specific environment to analyze
  --port PORT          Port for web server (default: 5000)
  --format FORMAT      Output format: html, svg, png (default: html)
  --path PATH          Root path for analysis (default: current directory)
```

### Examples

#### Generate Diagrams for All Environments

```bash
# Generate HTML diagrams
python blast-radius-integration.py --export

# Generate SVG diagrams
python blast-radius-integration.py --export --format svg

# Generate PNG diagrams
python blast-radius-integration.py --export --format png
```

#### Serve Specific Environment

```bash
# Serve eu-west-1 environment on default port (5000)
python blast-radius-integration.py --serve --env eu-west-1

# Serve dev environment on custom port
python blast-radius-integration.py --serve --env dev --port 8080
```

#### Analyze Custom Path

```bash
# Analyze a specific directory
python blast-radius-integration.py --export --path ./custom-path
```

### Make Commands

The Makefile provides convenient shortcuts:

```bash
# Install and setup
make blast-radius

# Export all diagrams
make blast-export

# Serve interactive diagrams
make blast-serve

# Clean generated files
make blast-clean

# Docker commands
make blast-docker
make blast-docker-all
make blast-docker-stop
```

## Docker Configuration

### Docker Compose Services

The `docker-compose.blast-radius.yml` file defines services for each environment:

- **blast-radius**: eu-west-1 environment (port 5000)
- **blast-radius-dev**: Development environment (port 5001)
- **blast-radius-staging**: Staging environment (port 5002)
- **blast-radius-prod**: Production environment (port 5003)

### Docker Commands

```bash
# Start all services
docker-compose -f docker-compose.blast-radius.yml up -d

# Start specific service
docker-compose -f docker-compose.blast-radius.yml up -d blast-radius

# View logs
docker-compose -f docker-compose.blast-radius.yml logs -f

# Stop all services
docker-compose -f docker-compose.blast-radius.yml down
```

## Output Structure

### Generated Files

When you run the export command, the following structure is created:

```
diagrams/
├── index.html                           # Main index page
├── README.md                            # Documentation
├── eu-west-1-dependency-diagram.html    # eu-west-1 environment
├── dev-dependency-diagram.html          # Development environment
├── staging-dependency-diagram.html      # Staging environment
└── prod-dependency-diagram.html         # Production environment
```

### Index Page

The `diagrams/index.html` file provides a central hub for accessing all diagrams:

- **Modern UI**: Clean, responsive design
- **Environment Cards**: Easy access to each environment
- **Interactive Features**: Links to interactive diagrams
- **Documentation**: Built-in help and usage instructions

## Integration with Existing Tools

### Terraform Dependency Analyzer

The Blast Radius integration works alongside the existing `terraform-dependency-analyzer.py`:

- **Complementary**: Blast Radius provides interactive visualizations
- **Different Focus**: Analyzer focuses on static analysis, Blast Radius on visualization
- **Shared Dependencies**: Both use similar Python libraries

### Makefile Integration

The Makefile now includes both traditional analysis and Blast Radius commands:

```bash
# Traditional analysis
make analyze
make dot
make mermaid

# Blast Radius integration
make blast-export
make blast-serve
make blast-docker
```

## Troubleshooting

### Common Issues

#### Blast Radius Not Found

```bash
# Install Blast Radius
pip install blastradius

# Or use Docker
make blast-docker
```

#### Graphviz Not Found

```bash
# macOS
brew install graphviz

# Ubuntu/Debian
sudo apt-get install graphviz

# Windows
# Download from https://graphviz.org/download/
```

#### Permission Errors

```bash
# Ensure write permissions
chmod -R 755 diagrams/

# Or run with sudo (if necessary)
sudo python blast-radius-integration.py --export
```

#### Port Conflicts

```bash
# Use different port
python blast-radius-integration.py --serve --env eu-west-1 --port 8080

# Or stop existing services
docker-compose -f docker-compose.blast-radius.yml down
```

#### Docker Issues

```bash
# Check Docker status
docker --version
docker-compose --version

# Restart Docker service
sudo systemctl restart docker

# Clean up containers
docker system prune -f
```

### Debug Commands

```bash
# Check Blast Radius installation
blast-radius --help

# Check Python dependencies
pip list | grep blastradius

# Check Docker containers
docker ps -a

# View logs
docker-compose -f docker-compose.blast-radius.yml logs
```

## Best Practices

### When to Use Blast Radius

- **Documentation**: Create interactive infrastructure documentation
- **Planning**: Visualize changes before applying them
- **Onboarding**: Help new team members understand the infrastructure
- **Debugging**: Identify dependency issues and circular references
- **Presentations**: Create visual aids for stakeholder presentations

### Workflow Integration

1. **Development**: Use interactive diagrams during development
2. **Code Review**: Include diagrams in pull requests
3. **Deployment**: Verify dependencies before deployment
4. **Documentation**: Keep diagrams updated with infrastructure changes

### Performance Considerations

- **Large Graphs**: For very large dependency graphs, consider filtering
- **Memory Usage**: Docker containers may use significant memory
- **Network**: Web interface requires network access for external resources

## Contributing

### Adding New Environments

1. **Update Scripts**: Modify `blast-radius-integration.py` to detect new environments
2. **Update Docker**: Add new services to `docker-compose.blast-radius.yml`
3. **Update Makefile**: Add new commands to Makefile
4. **Test**: Verify diagrams are generated correctly
5. **Document**: Update this documentation

### Customizing Diagrams

1. **Styling**: Modify the HTML templates in the integration script
2. **Features**: Extend the Blast Radius functionality
3. **Integration**: Add integration with other tools

## Resources

### Documentation

- [Blast Radius GitHub](https://github.com/28mm/blast-radius)
- [Blast Radius Documentation](https://28mm.github.io/blast-radius-docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)

### Examples

- [AWS Two-Tier Architecture](https://28mm.github.io/blast-radius-docs/examples/aws-two-tier/)
- [AWS Networking with Modules](https://28mm.github.io/blast-radius-docs/examples/aws-networking/)
- [Google Two-Tier Architecture](https://28mm.github.io/blast-radius-docs/examples/google-two-tier/)
- [Azure Load Balancing](https://28mm.github.io/blast-radius-docs/examples/azure-load-balancing/)

### Community

- [Blast Radius Issues](https://github.com/28mm/blast-radius/issues)
- [Terraform Community](https://discuss.hashicorp.com/c/terraform-core)
- [Terragrunt Community](https://github.com/gruntwork-io/terragrunt/discussions)

---

*This integration was created to enhance the terragrunt-olechka repository with interactive Terraform dependency visualization capabilities.* 