# Terraform Dependency Analyzer Makefile

.PHONY: help install test analyze clean all-formats dot mermaid html json blast-radius blast-serve blast-export

# Default target
help:
	@echo "Terraform Dependency Analyzer - Available Commands:"
	@echo ""
	@echo "  install     - Install Python dependencies"
	@echo "  test        - Run test script to analyze current structure"
	@echo "  analyze     - Run basic analysis (JSON output)"
	@echo "  all-formats - Generate all visualization formats"
	@echo "  dot         - Generate DOT graph for Graphviz"
	@echo "  mermaid     - Generate Mermaid diagram"
	@echo "  html        - Generate interactive HTML visualization"
	@echo "  json        - Generate JSON analysis report"
	@echo "  clean       - Remove generated files"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Blast Radius Integration:"
	@echo "  blast-radius - Install and setup Blast Radius"
	@echo "  blast-serve  - Serve interactive diagrams via web interface"
	@echo "  blast-export - Export all diagrams to files"
	@echo "  blast-clean  - Clean generated diagram files"
	@echo ""
	@echo "Docker Blast Radius:"
	@echo "  blast-docker     - Start Blast Radius with Docker (eu-west-1)"
	@echo "  blast-docker-all - Start all environments with Docker"
	@echo "  blast-docker-stop- Stop all Docker containers"
	@echo ""
	@echo "Testing:"
	@echo "  test-blast      - Test Blast Radius integration"

# Install dependencies
install:
	@echo "📦 Installing Python dependencies..."
	pip install -r requirements.txt
	@echo "✅ Dependencies installed"

# Run test script
test:
	@echo "🧪 Running test analysis..."
	python test-analyzer.py

# Basic analysis
analyze:
	@echo "🔍 Running Terraform dependency analysis..."
	python terraform-dependency-analyzer.py --format json --output analysis.json
	@echo "✅ Analysis complete: analysis.json"

# Generate all formats
all-formats: dot mermaid html json
	@echo "🎨 All visualization formats generated!"

# Generate DOT graph
dot:
	@echo "📊 Generating DOT graph..."
	python terraform-dependency-analyzer.py --format dot --output dependency-graph.dot
	@echo "✅ DOT graph generated: dependency-graph.dot"
	@echo "💡 To generate PNG: dot -Tpng dependency-graph.dot -o dependency-graph.png"

# Generate Mermaid diagram
mermaid:
	@echo "📈 Generating Mermaid diagram..."
	python terraform-dependency-analyzer.py --format mermaid --output dependency-graph.md
	@echo "✅ Mermaid diagram generated: dependency-graph.md"

# Generate HTML visualization
html:
	@echo "🌐 Generating HTML visualization..."
	python terraform-dependency-analyzer.py --format html --output dependency-graph.html
	@echo "✅ HTML visualization generated: dependency-graph.html"
	@echo "💡 Open dependency-graph.html in your web browser"

# Generate JSON report
json:
	@echo "📄 Generating JSON report..."
	python terraform-dependency-analyzer.py --format json --output analysis.json
	@echo "✅ JSON report generated: analysis.json"

# Analyze specific path
analyze-path:
	@echo "🔍 Analyzing specific path..."
	@read -p "Enter path to analyze: " path; \
	python terraform-dependency-analyzer.py --path $$path --format json --output analysis-$$(basename $$path).json
	@echo "✅ Analysis complete"

# Clean generated files
clean:
	@echo "🧹 Cleaning generated files..."
	rm -f *.dot *.md *.html *.json
	@echo "✅ Cleaned"

# Quick analysis with summary
quick:
	@echo "⚡ Quick analysis..."
	python terraform-dependency-analyzer.py --format json
	@echo "✅ Quick analysis complete"

# Analyze all environments
analyze-all:
	@echo "🌍 Analyzing all environments..."
	@for env in eu-west-1 dev prod staging; do \
		if [ -d "$$env" ]; then \
			echo "Analyzing $$env..."; \
			python terraform-dependency-analyzer.py --path $$env --format json --output analysis-$$env.json; \
		fi; \
	done
	@echo "✅ All environments analyzed"

# Generate PNG from DOT (requires Graphviz)
png: dot
	@echo "🖼️  Generating PNG from DOT..."
	@if command -v dot >/dev/null 2>&1; then \
		dot -Tpng dependency-graph.dot -o dependency-graph.png; \
		echo "✅ PNG generated: dependency-graph.png"; \
	else \
		echo "❌ Graphviz not found. Install with: brew install graphviz (Mac) or apt-get install graphviz (Ubuntu)"; \
	fi

# Interactive mode
interactive:
	@echo "🎯 Interactive Terraform Dependency Analyzer"
	@echo "1. Analyze current directory"
	@echo "2. Analyze specific path"
	@echo "3. Generate all visualizations"
	@echo "4. Quick analysis"
	@echo "5. Exit"
	@read -p "Choose option (1-5): " choice; \
	case $$choice in \
		1) python terraform-dependency-analyzer.py --format json --output analysis.json ;; \
		2) make analyze-path ;; \
		3) make all-formats ;; \
		4) make quick ;; \
		5) echo "Goodbye!" ;; \
		*) echo "Invalid option" ;; \
	esac

# Blast Radius Integration
blast-radius:
	@echo "🚀 Setting up Blast Radius integration..."
	python blast-radius-integration.py --export
	@echo "✅ Blast Radius setup complete"

blast-serve:
	@echo "🌐 Starting Blast Radius web server..."
	@echo "Available environments:"
	@python blast-radius-integration.py --help | grep -A 10 "Examples:" || true
	@read -p "Enter environment name (e.g., eu-west-1): " env; \
	python blast-radius-integration.py --serve --env $$env

blast-export:
	@echo "📊 Exporting all Blast Radius diagrams..."
	python blast-radius-integration.py --export
	@echo "✅ Diagrams exported to diagrams/ directory"

blast-clean:
	@echo "🧹 Cleaning Blast Radius generated files..."
	rm -rf diagrams/
	@echo "✅ Blast Radius files cleaned"

# Docker-based Blast Radius
blast-docker:
	@echo "🐳 Starting Blast Radius with Docker..."
	docker-compose -f docker-compose.blast-radius.yml up -d blast-radius
	@echo "✅ Blast Radius running at http://localhost:5000"

blast-docker-all:
	@echo "🐳 Starting all Blast Radius environments with Docker..."
	docker-compose -f docker-compose.blast-radius.yml up -d
	@echo "✅ All environments running:"
	@echo "  - eu-west-1: http://localhost:5000"
	@echo "  - dev: http://localhost:5001"
	@echo "  - staging: http://localhost:5002"
	@echo "  - prod: http://localhost:5003"

blast-docker-stop:
	@echo "🛑 Stopping Blast Radius Docker containers..."
	docker-compose -f docker-compose.blast-radius.yml down
	@echo "✅ Docker containers stopped"

# Testing
test-blast:
	@echo "🧪 Testing Blast Radius integration..."
	python test-blast-radius.py 