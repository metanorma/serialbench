# frozen_string_literal: true

require 'json'
require 'yaml'
require 'fileutils'
require 'time'
require_relative 'template_renderer'
require_relative 'models'

module Serialbench
  class ResultMerger
    attr_reader :merged_results

    def initialize(output_dir = 'results')
      @output_dir = output_dir
      @charts_dir = File.join(output_dir, 'charts')
      @reports_dir = File.join(output_dir, 'reports')
      @assets_dir = File.join(output_dir, 'assets')
      @merged_results = nil
    end

    # Main report generation method for single benchmark results
    def generate_all_reports(results)
      setup_directories

      # Generate CSS
      generate_css

      # Generate combined HTML report directly
      html_file = File.join(@reports_dir, 'benchmark_report.html')
      generate_combined_html_report(results, html_file)

      {
        html: html_file,
        css: File.join(@assets_dir, 'css', 'benchmark_report.css')
      }
    end

    # Generate standalone HTML report for single benchmark results
    def generate_combined_html_report(results, html_file)
      setup_directories
      html_content = generate_single_benchmark_html(results)
      File.write(html_file, html_content)
    end

    def merge_files(result_files)
      # Initialize merged results model
      @merged_results = Serialbench::Models::MergedBenchmarkResult.new

      result_files.each do |file_path|
        unless File.exist?(file_path)
          puts "Warning: File not found: #{file_path}"
          next
        end

        begin
          # Load using model system
          benchmark_result = Serialbench::Models.from_file(file_path)
          merge_benchmark_result(benchmark_result, file_path)
        rescue => e
          puts "Warning: Error processing #{file_path}: #{e.message}"
          next
        end
      end

      @merged_results
    end

    def merge_directories(input_dirs, output_dir)
      FileUtils.mkdir_p(output_dir)

      result_files = []

      input_dirs.each do |dir|
        unless Dir.exist?(dir)
          puts "Warning: Directory not found: #{dir}"
          next
        end

        # Look for results files (prefer YAML, fallback to JSON)
        yaml_pattern = File.join(dir, '**/results.{yaml,yml}')
        json_pattern = File.join(dir, '**/results.json')

        found_files = Dir.glob(yaml_pattern)
        found_files.concat(Dir.glob(json_pattern)) if found_files.empty?

        if found_files.empty?
          # Also check for files directly in the directory
          %w[results.yaml results.yml results.json].each do |filename|
            direct_file = File.join(dir, filename)
            found_files << direct_file if File.exist?(direct_file)
            break unless found_files.empty?
          end
        end

        result_files.concat(found_files)
      end

      raise 'No results files found in the specified directories' if result_files.empty?

      puts "Found #{result_files.length} result files to merge:"
      result_files.each { |file| puts "  - #{file}" }

      merge_files(result_files)

      # Save merged results (primary format: YAML)
      output_yaml = File.join(output_dir, 'merged_results.yaml')
      @merged_results.to_yaml_file(output_yaml)

      # Also save as JSON for HTML templates
      output_json = File.join(output_dir, 'merged_results.json')
      @merged_results.to_json_file(output_json)

      puts "Merged results saved to:"
      puts "  YAML: #{output_yaml}"
      puts "  JSON: #{output_json}"

      output_yaml
    end

    def generate_github_pages_html(output_dir)
      FileUtils.mkdir_p(output_dir)

      # Use new template system for multi-version reports
      renderer = TemplateRenderer.new
      renderer.render_multi_version(@merged_results.to_hash, output_dir)

      index_file = File.join(output_dir, 'index.html')
      css_file = File.join(output_dir, 'styles.css')

      # Also generate the legacy version for backward compatibility
      legacy_html = generate_combined_html
      File.write(File.join(output_dir, 'legacy.html'), legacy_html)
      File.write(css_file, generate_css)

      puts "GitHub Pages HTML generated: #{index_file}"
      puts "CSS file generated: #{css_file}"

      {
        html: index_file,
        css: css_file
      }
    end

    def generate_modern_html(output_dir)
      renderer = TemplateRenderer.new
      renderer.render_multi_version(@merged_results.to_hash, output_dir)
      File.join(output_dir, 'index.html')
    end

    private

    def merge_benchmark_result(benchmark_result, source_file)
      # Extract environment info
      ruby_version = benchmark_result.ruby_version
      ruby_platform = benchmark_result.ruby_platform
      timestamp = benchmark_result.timestamp

      env_key = "#{ruby_version}_#{ruby_platform}".gsub(/[^a-zA-Z0-9_]/, '_')

      # Add environment info
      env_info = {
        'ruby_version' => ruby_version,
        'ruby_platform' => ruby_platform,
        'source_file' => source_file,
        'timestamp' => timestamp,
        'environment' => benchmark_result.environment.to_hash
      }

      @merged_results.add_environment(env_key, env_info)

      # Update metadata
      @merged_results.metadata.add_ruby_version(ruby_version)
      @merged_results.metadata.add_platform(ruby_platform)

      # Merge benchmark results
      merge_operation_results('parsing', benchmark_result.parsing, env_key)
      merge_operation_results('generation', benchmark_result.generation, env_key)
      merge_operation_results('streaming', benchmark_result.streaming, env_key)
      merge_memory_results(benchmark_result.memory, env_key)
    end

    def merge_operation_results(operation_name, operation_results, env_key)
      return if operation_results.empty?

      combined_operation = case operation_name
                          when 'parsing'
                            @merged_results.combined_results.parsing
                          when 'generation'
                            @merged_results.combined_results.generation
                          when 'streaming'
                            @merged_results.combined_results.streaming
                          end

      %w[small medium large].each do |size|
        size_results = case size
                      when 'small'
                        operation_results.small
                      when 'medium'
                        operation_results.medium
                      when 'large'
                        operation_results.large
                      end

        next if size_results.empty?

        combined_size = case size
                       when 'small'
                         combined_operation.small
                       when 'medium'
                         combined_operation.medium
                       when 'large'
                         combined_operation.large
                       end

        %w[xml json yaml toml].each do |format|
          format_results = case format
                          when 'xml'
                            size_results.xml
                          when 'json'
                            size_results.json
                          when 'yaml'
                            size_results.yaml
                          when 'toml'
                            size_results.toml
                          end

          next if format_results.empty?

          combined_format = case format
                           when 'xml'
                             combined_size.xml
                           when 'json'
                             combined_size.json
                           when 'yaml'
                             combined_size.yaml
                           when 'toml'
                             combined_size.toml
                           end

          format_results.serializers.each do |serializer|
            perf_data = format_results[serializer]
            combined_format.add_result(serializer, env_key, perf_data)
          end
        end
      end
    end

    def merge_memory_results(memory_results, env_key)
      return if memory_results.empty?

      %w[small medium large].each do |size|
        size_results = case size
                      when 'small'
                        memory_results.small
                      when 'medium'
                        memory_results.medium
                      when 'large'
                        memory_results.large
                      end

        next if size_results.empty?

        combined_size = case size
                       when 'small'
                         @merged_results.combined_results.memory.small
                       when 'medium'
                         @merged_results.combined_results.memory.medium
                       when 'large'
                         @merged_results.combined_results.memory.large
                       end

        %w[xml json yaml toml].each do |format|
          format_results = case format
                          when 'xml'
                            size_results.xml
                          when 'json'
                            size_results.json
                          when 'yaml'
                            size_results.yaml
                          when 'toml'
                            size_results.toml
                          end

          next if format_results.empty?

          combined_format = case format
                           when 'xml'
                             combined_size.xml
                           when 'json'
                             combined_size.json
                           when 'yaml'
                             combined_size.yaml
                           when 'toml'
                             combined_size.toml
                           end

          format_results.serializers.each do |serializer|
            mem_data = format_results[serializer]
            combined_format.add_result(serializer, env_key, mem_data)
          end
        end
      end
    end

    def generate_combined_html
      return '' unless @merged_results

      merged_hash = @merged_results.to_hash

      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Serialbench - Multi-Ruby Version Comparison</title>
            <link rel="stylesheet" href="styles.css">
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>Serialbench - Multi-Ruby Version Comparison</h1>
                    <p class="subtitle">Comprehensive serialization performance benchmarks across Ruby versions</p>
                    <div class="metadata">
                        <p><strong>Generated:</strong> #{merged_hash['metadata']['merged_at']}</p>
                        <p><strong>Ruby Versions:</strong> #{merged_hash['metadata']['ruby_versions'].join(', ')}</p>
                        <p><strong>Platforms:</strong> #{merged_hash['metadata']['platforms'].join(', ')}</p>
                    </div>
                </header>

                <nav class="benchmark-nav">
                    <button class="nav-btn active" onclick="showSection('parsing')">Parsing Performance</button>
                    <button class="nav-btn" onclick="showSection('generation')">Generation Performance</button>
                    <button class="nav-btn" onclick="showSection('streaming')">Streaming Performance</button>
                    <button class="nav-btn" onclick="showSection('memory')">Memory Usage</button>
                    <button class="nav-btn" onclick="showSection('environments')">Environment Details</button>
                </nav>

                <div id="parsing" class="section active">
                    <h2>Parsing Performance Comparison</h2>
                    <p>Charts will be generated here...</p>
                </div>

                <div id="generation" class="section">
                    <h2>Generation Performance Comparison</h2>
                    <p>Charts will be generated here...</p>
                </div>

                <div id="streaming" class="section">
                    <h2>Streaming Performance Comparison</h2>
                    <p>Charts will be generated here...</p>
                </div>

                <div id="memory" class="section">
                    <h2>Memory Usage Comparison</h2>
                    <p>Charts will be generated here...</p>
                </div>

                <div id="environments" class="section">
                    <h2>Environment Details</h2>
                    <p>Environment information will be displayed here...</p>
                </div>
            </div>

            <script>
                function showSection(sectionName) {
                    document.querySelectorAll('.section').forEach(section => {
                        section.classList.remove('active');
                    });

                    document.querySelectorAll('.nav-btn').forEach(btn => {
                        btn.classList.remove('active');
                    });

                    document.getElementById(sectionName).classList.add('active');
                    event.target.classList.add('active');
                }
            </script>
        </body>
        </html>
      HTML
    end

    # Generate HTML for single benchmark results (not multi-version)
    def generate_single_benchmark_html(results)
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Serialbench - Performance Report</title>
            <link rel="stylesheet" href="../assets/css/benchmark_report.css">
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>Serialbench - Performance Report</h1>
                    <p class="subtitle">Comprehensive serialization performance benchmarks</p>
                    <div class="metadata">
                        <p><strong>Generated:</strong> #{Time.now.strftime('%B %d, %Y at %H:%M')}</p>
                        <p><strong>Ruby Version:</strong> #{results[:environment][:ruby_version]}</p>
                        <p><strong>Platform:</strong> #{results[:environment][:ruby_platform]}</p>
                    </div>
                </header>

                <nav class="benchmark-nav">
                    <button class="nav-btn active" onclick="showSection('parsing')">Parsing Performance</button>
                    <button class="nav-btn" onclick="showSection('generation')">Generation Performance</button>
                    <button class="nav-btn" onclick="showSection('streaming')">Streaming Performance</button>
                    <button class="nav-btn" onclick="showSection('memory')">Memory Usage</button>
                    <button class="nav-btn" onclick="showSection('summary')">Summary</button>
                </nav>

                <div id="parsing" class="section active">
                    <h2>Parsing Performance</h2>
                    <p>Parsing performance charts will be displayed here...</p>
                </div>

                <div id="generation" class="section">
                    <h2>Generation Performance</h2>
                    <p>Generation performance charts will be displayed here...</p>
                </div>

                <div id="streaming" class="section">
                    <h2>Streaming Performance</h2>
                    <p>Streaming performance charts will be displayed here...</p>
                </div>

                <div id="memory" class="section">
                    <h2>Memory Usage</h2>
                    <p>Memory usage charts will be displayed here...</p>
                </div>

                <div id="summary" class="section">
                    <h2>Performance Summary</h2>
                    <div class="summary-grid">
                        <div class="summary-card">
                            <h3>Key Findings</h3>
                            <p>Analysis pending - benchmark data processing in progress.</p>
                        </div>
                        <div class="summary-card">
                            <h3>Recommendations</h3>
                            <ul>
                                <li><strong>For built-in support:</strong> JSON and REXML require no additional dependencies</li>
                                <li><strong>For streaming large files:</strong> Consider SAX/streaming parsers when available</li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>

            <script>
                function showSection(sectionName) {
                    document.querySelectorAll('.section').forEach(section => {
                        section.classList.remove('active');
                    });

                    document.querySelectorAll('.nav-btn').forEach(btn => {
                        btn.classList.remove('active');
                    });

                    document.getElementById(sectionName).classList.add('active');
                    event.target.classList.add('active');
                }
            </script>
        </body>
        </html>
      HTML
    end

    def setup_directories
      [@output_dir, @charts_dir, @reports_dir, @assets_dir].each do |dir|
        FileUtils.mkdir_p(dir)
      end
      FileUtils.mkdir_p(File.join(@assets_dir, 'css'))
    end

    def generate_css
      css_content = <<~CSS
        /* Serialbench Report Styles */
        :root {
          --primary-color: #2c3e50;
          --secondary-color: #3498db;
          --accent-color: #e74c3c;
          --success-color: #27ae60;
          --warning-color: #f39c12;
          --background-color: #ffffff;
          --text-color: #2c3e50;
          --border-color: #bdc3c7;
          --light-bg: #f8f9fa;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: var(--text-color);
            background-color: var(--light-bg);
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }

        header {
            text-align: center;
            margin-bottom: 40px;
            padding: 40px 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 10px;
        }

        header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }

        .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
            margin-bottom: 20px;
        }

        .metadata {
            display: flex;
            justify-content: center;
            gap: 30px;
            flex-wrap: wrap;
            font-size: 0.9em;
        }

        .benchmark-nav {
            display: flex;
            justify-content: center;
            gap: 10px;
            margin-bottom: 40px;
            flex-wrap: wrap;
        }

        .nav-btn {
            padding: 12px 24px;
            border: none;
            background-color: #e9ecef;
            color: #495057;
            border-radius: 25px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-weight: 500;
        }

        .nav-btn:hover {
            background-color: #dee2e6;
            transform: translateY(-2px);
        }

        .nav-btn.active {
            background-color: var(--secondary-color);
            color: white;
        }

        .section {
            display: none;
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }

        .section.active {
            display: block;
        }

        .section h2 {
            color: var(--primary-color);
            margin-bottom: 30px;
            font-size: 2em;
            border-bottom: 3px solid var(--secondary-color);
            padding-bottom: 10px;
        }

        .section h3 {
            color: #34495e;
            margin: 30px 0 20px 0;
            font-size: 1.5em;
        }

        .charts-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }

        .chart-container {
            background: var(--light-bg);
            padding: 20px;
            border-radius: 8px;
            border: 1px solid var(--border-color);
        }

        .chart-container h4 {
            text-align: center;
            margin-bottom: 15px;
            color: #495057;
            font-size: 1.1em;
        }

        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
        }

        .summary-card {
            background: var(--light-bg);
            padding: 25px;
            border-radius: 8px;
            border: 1px solid var(--border-color);
        }

        .summary-card h3 {
            color: var(--secondary-color);
            margin-bottom: 15px;
            font-size: 1.3em;
        }

        .summary-card ul {
            list-style: none;
            padding-left: 0;
        }

        .summary-card li {
            padding: 8px 0;
            border-bottom: 1px solid #eee;
        }

        .summary-card li:last-child {
            border-bottom: none;
        }

        .environments-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }

        .environment-card {
            background: var(--light-bg);
            padding: 20px;
            border-radius: 8px;
            border: 1px solid var(--border-color);
        }

        .environment-card h3 {
            color: var(--secondary-color);
            margin-bottom: 15px;
            font-size: 1.2em;
        }

        .environment-card p {
            margin-bottom: 8px;
            color: #6c757d;
        }

        .serializer-versions {
            margin-top: 15px;
        }

        .serializer-versions h4 {
            color: #495057;
            margin-bottom: 10px;
            font-size: 1em;
        }

        .serializer-versions ul {
            list-style: none;
            padding-left: 0;
        }

        .serializer-versions li {
            padding: 4px 0;
            color: #6c757d;
            font-size: 0.9em;
        }

        @media (max-width: 768px) {
            .container {
                padding: 10px;
            }

            header {
                padding: 20px 10px;
            }

            header h1 {
                font-size: 2em;
            }

            .metadata {
                flex-direction: column;
                gap: 10px;
            }

            .charts-grid {
                grid-template-columns: 1fr;
            }

            .chart-container {
                padding: 15px;
            }

            .summary-grid {
                grid-template-columns: 1fr;
            }
        }
      CSS

      File.write(File.join(@assets_dir, 'css', 'benchmark_report.css'), css_content)
    end
  end
end
