# frozen_string_literal: true

require 'json'
require 'fileutils'

module Serialbench
  class ResultMerger
    attr_reader :merged_results

    def initialize(output_dir = 'results')
      @output_dir = output_dir
      @charts_dir = File.join(output_dir, 'charts')
      @reports_dir = File.join(output_dir, 'reports')
      @assets_dir = File.join(output_dir, 'assets')
      @merged_results = {
        environments: {},
        combined_results: {},
        metadata: {
          merged_at: Time.now.iso8601,
          ruby_versions: [],
          platforms: []
        }
      }
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

    def merge_files(json_files)
      json_files.each do |file_path|
        unless File.exist?(file_path)
          puts "Warning: File not found: #{file_path}"
          next
        end

        begin
          data = JSON.parse(File.read(file_path), symbolize_names: true)
          merge_result_data(data, file_path)
        rescue JSON::ParserError => e
          puts "Warning: Invalid JSON in #{file_path}: #{e.message}"
          next
        end
      end

      @merged_results
    end

    def merge_directories(input_dirs, output_dir)
      FileUtils.mkdir_p(output_dir)

      json_files = []

      input_dirs.each do |dir|
        unless Dir.exist?(dir)
          puts "Warning: Directory not found: #{dir}"
          next
        end

        # Look for results.json files in subdirectories
        pattern = File.join(dir, '**/results.json')
        found_files = Dir.glob(pattern)

        if found_files.empty?
          # Also check for results.json directly in the directory
          direct_file = File.join(dir, 'results.json')
          found_files << direct_file if File.exist?(direct_file)
        end

        json_files.concat(found_files)
      end

      raise 'No results.json files found in the specified directories' if json_files.empty?

      puts "Found #{json_files.length} result files to merge:"
      json_files.each { |file| puts "  - #{file}" }

      merge_files(json_files)

      # Save merged results
      output_file = File.join(output_dir, 'merged_results.json')
      File.write(output_file, JSON.pretty_generate(@merged_results))

      puts "Merged results saved to: #{output_file}"
      output_file
    end

    def generate_github_pages_html(output_dir)
      FileUtils.mkdir_p(output_dir)

      html_content = generate_combined_html

      # Save as index.html for GitHub Pages
      index_file = File.join(output_dir, 'index.html')
      File.write(index_file, html_content)

      # Also save CSS file
      css_file = File.join(output_dir, 'styles.css')
      File.write(css_file, generate_css)

      puts "GitHub Pages HTML generated: #{index_file}"
      puts "CSS file generated: #{css_file}"

      {
        html: index_file,
        css: css_file
      }
    end

    private

    def merge_result_data(data, source_file)
      # Extract environment info
      ruby_version = data[:ruby_version] || data[:environment]&.dig(:ruby_version) || 'unknown'
      ruby_platform = data[:ruby_platform] || data[:environment]&.dig(:ruby_platform) || 'unknown'

      env_key = "#{ruby_version}_#{ruby_platform}".gsub(/[^a-zA-Z0-9_]/, '_')

      @merged_results[:environments][env_key] = {
        ruby_version: ruby_version,
        ruby_platform: ruby_platform,
        source_file: source_file,
        timestamp: data[:timestamp],
        environment: data[:environment]
      }

      # Track unique Ruby versions and platforms
      unless @merged_results[:metadata][:ruby_versions].include?(ruby_version)
        @merged_results[:metadata][:ruby_versions] << ruby_version
      end
      unless @merged_results[:metadata][:platforms].include?(ruby_platform)
        @merged_results[:metadata][:platforms] << ruby_platform
      end

      # Merge benchmark results
      %i[parsing generation streaming memory_usage].each do |benchmark_type|
        next unless data[benchmark_type]

        @merged_results[:combined_results][benchmark_type] ||= {}

        data[benchmark_type].each do |size, size_data|
          @merged_results[:combined_results][benchmark_type][size] ||= {}

          size_data.each do |format, format_data|
            @merged_results[:combined_results][benchmark_type][size][format] ||= {}

            format_data.each do |serializer, serializer_data|
              @merged_results[:combined_results][benchmark_type][size][format][serializer] ||= {}
              @merged_results[:combined_results][benchmark_type][size][format][serializer][env_key] = serializer_data
            end
          end
        end
      end
    end

    def generate_combined_html
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>SerialBench - Multi-Ruby Version Comparison</title>
            <link rel="stylesheet" href="styles.css">
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>SerialBench - Multi-Ruby Version Comparison</h1>
                    <p class="subtitle">Comprehensive serialization performance benchmarks across Ruby versions</p>
                    <div class="metadata">
                        <p><strong>Generated:</strong> #{@merged_results[:metadata][:merged_at]}</p>
                        <p><strong>Ruby Versions:</strong> #{@merged_results[:metadata][:ruby_versions].join(', ')}</p>
                        <p><strong>Platforms:</strong> #{@merged_results[:metadata][:platforms].join(', ')}</p>
                    </div>
                </header>

                <nav class="benchmark-nav">
                    <button class="nav-btn active" onclick="showSection('parsing')">Parsing Performance</button>
                    <button class="nav-btn" onclick="showSection('generation')">Generation Performance</button>
                    <button class="nav-btn" onclick="showSection('streaming')">Streaming Performance</button>
                    <button class="nav-btn" onclick="showSection('memory')">Memory Usage</button>
                    <button class="nav-btn" onclick="showSection('environments')">Environment Details</button>
                </nav>

                #{generate_parsing_section}
                #{generate_generation_section}
                #{generate_streaming_section}
                #{generate_memory_section}
                #{generate_environments_section}
            </div>

            <script>
                #{generate_javascript}
            </script>
        </body>
        </html>
      HTML
    end

    def generate_parsing_section
      unless @merged_results[:combined_results][:parsing]
        return '<div id="parsing" class="section active"><p>No parsing data available</p></div>'
      end

      content = '<div id="parsing" class="section active">'
      content += '<h2>Parsing Performance Comparison</h2>'

      %i[small medium large].each do |size|
        next unless @merged_results[:combined_results][:parsing][size]

        content += "<h3>#{size.capitalize} Files</h3>"
        content += '<div class="charts-grid">'

        @merged_results[:combined_results][:parsing][size].each do |format, format_data|
          content += generate_performance_chart("parsing_#{size}_#{format}", "#{format.upcase} Parsing (#{size})",
                                                format_data, 'iterations_per_second')
        end

        content += '</div>'
      end

      content += '</div>'
    end

    def generate_generation_section
      unless @merged_results[:combined_results][:generation]
        return '<div id="generation" class="section"><p>No generation data available</p></div>'
      end

      content = '<div id="generation" class="section">'
      content += '<h2>Generation Performance Comparison</h2>'

      %i[small medium large].each do |size|
        next unless @merged_results[:combined_results][:generation][size]

        content += "<h3>#{size.capitalize} Files</h3>"
        content += '<div class="charts-grid">'

        @merged_results[:combined_results][:generation][size].each do |format, format_data|
          content += generate_performance_chart("generation_#{size}_#{format}",
                                                "#{format.upcase} Generation (#{size})", format_data, 'iterations_per_second')
        end

        content += '</div>'
      end

      content += '</div>'
    end

    def generate_streaming_section
      unless @merged_results[:combined_results][:streaming]
        return '<div id="streaming" class="section"><p>No streaming data available</p></div>'
      end

      content = '<div id="streaming" class="section">'
      content += '<h2>Streaming Performance Comparison</h2>'

      %i[small medium large].each do |size|
        next unless @merged_results[:combined_results][:streaming][size]

        content += "<h3>#{size.capitalize} Files</h3>"
        content += '<div class="charts-grid">'

        @merged_results[:combined_results][:streaming][size].each do |format, format_data|
          content += generate_performance_chart("streaming_#{size}_#{format}", "#{format.upcase} Streaming (#{size})",
                                                format_data, 'iterations_per_second')
        end

        content += '</div>'
      end

      content += '</div>'
    end

    def generate_memory_section
      unless @merged_results[:combined_results][:memory_usage]
        return '<div id="memory" class="section"><p>No memory data available</p></div>'
      end

      content = '<div id="memory" class="section">'
      content += '<h2>Memory Usage Comparison</h2>'

      %i[small medium large].each do |size|
        next unless @merged_results[:combined_results][:memory_usage][size]

        content += "<h3>#{size.capitalize} Files</h3>"
        content += '<div class="charts-grid">'

        @merged_results[:combined_results][:memory_usage][size].each do |format, format_data|
          content += generate_memory_chart("memory_#{size}_#{format}", "#{format.upcase} Memory Usage (#{size})",
                                           format_data)
        end

        content += '</div>'
      end

      content += '</div>'
    end

    def generate_environments_section
      content = '<div id="environments" class="section">'
      content += '<h2>Environment Details</h2>'
      content += '<div class="environments-grid">'

      @merged_results[:environments].each do |env_key, env_data|
        content += <<~ENV
          <div class="environment-card">
              <h3>#{env_data[:ruby_version]} on #{env_data[:ruby_platform]}</h3>
              <p><strong>Source:</strong> #{File.basename(env_data[:source_file])}</p>
              <p><strong>Timestamp:</strong> #{env_data[:timestamp]}</p>
              #{generate_serializer_versions(env_data[:environment])}
          </div>
        ENV
      end

      content += '</div></div>'
    end

    def generate_serializer_versions(environment)
      return '' unless environment&.dig(:serializer_versions)

      content = '<div class="serializer-versions">'
      content += '<h4>Serializer Versions:</h4>'
      content += '<ul>'

      environment[:serializer_versions].each do |name, version|
        content += "<li><strong>#{name}:</strong> #{version}</li>"
      end

      content += '</ul></div>'
    end

    def generate_performance_chart(chart_id, title, data, metric)
      # Store chart data for later initialization
      @chart_initializers ||= []
      @chart_initializers << "createPerformanceChart('#{chart_id}', '#{title}', #{data.to_json}, '#{metric}');"

      <<~CHART
        <div class="chart-container">
            <h4>#{title}</h4>
            <canvas id="#{chart_id}" width="400" height="300"></canvas>
        </div>
      CHART
    end

    def generate_memory_chart(chart_id, title, data)
      # Store chart data for later initialization
      @chart_initializers ||= []
      @chart_initializers << "createMemoryChart('#{chart_id}', '#{title}', #{data.to_json});"

      <<~CHART
        <div class="chart-container">
            <h4>#{title}</h4>
            <canvas id="#{chart_id}" width="400" height="300"></canvas>
        </div>
      CHART
    end

    def generate_javascript
      chart_init_code = @chart_initializers ? @chart_initializers.join("\n        ") : ''

      <<~JS
        function showSection(sectionName) {
            // Hide all sections
            document.querySelectorAll('.section').forEach(section => {
                section.classList.remove('active');
            });

            // Remove active class from all nav buttons
            document.querySelectorAll('.nav-btn').forEach(btn => {
                btn.classList.remove('active');
            });

            // Show selected section
            document.getElementById(sectionName).classList.add('active');

            // Add active class to clicked button
            event.target.classList.add('active');
        }

        function createPerformanceChart(canvasId, title, data, metric) {
            const ctx = document.getElementById(canvasId).getContext('2d');

            const environments = #{@merged_results[:environments].keys.to_json};
            const serializers = Object.keys(data);

            const datasets = serializers.map((serializer, index) => {
                const serializerData = data[serializer];
                const values = environments.map(env => {
                    const envData = serializerData[env];
                    return envData ? (envData[metric] || 0) : 0;
                });

                return {
                    label: serializer,
                    data: values,
                    backgroundColor: `hsl(${index * 60}, 70%, 50%)`,
                    borderColor: `hsl(${index * 60}, 70%, 40%)`,
                    borderWidth: 1
                };
            });

            const environmentLabels = environments.map(env => {
                const envData = #{@merged_results[:environments].to_json}[env];
                return envData.ruby_version + ' (' + envData.ruby_platform + ')';
            });

            new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: environmentLabels,
                    datasets: datasets
                },
                options: {
                    responsive: true,
                    plugins: {
                        title: {
                            display: true,
                            text: title
                        },
                        legend: {
                            position: 'top'
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: {
                                display: true,
                                text: metric === 'iterations_per_second' ? 'Operations/Second' : 'Time (ms)'
                            }
                        }
                    }
                }
            });
        }

        function createMemoryChart(canvasId, title, data) {
            const ctx = document.getElementById(canvasId).getContext('2d');

            const environments = #{@merged_results[:environments].keys.to_json};
            const serializers = Object.keys(data);

            const datasets = serializers.map((serializer, index) => {
                const serializerData = data[serializer];
                const values = environments.map(env => {
                    const envData = serializerData[env];
                    return envData ? (envData.allocated_memory / 1024 / 1024) : 0; // Convert to MB
                });

                return {
                    label: serializer,
                    data: values,
                    backgroundColor: `hsl(${index * 60}, 70%, 50%)`,
                    borderColor: `hsl(${index * 60}, 70%, 40%)`,
                    borderWidth: 1
                };
            });

            const environmentLabels = environments.map(env => {
                const envData = #{@merged_results[:environments].to_json}[env];
                return envData.ruby_version + ' (' + envData.ruby_platform + ')';
            });

            new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: environmentLabels,
                    datasets: datasets
                },
                options: {
                    responsive: true,
                    plugins: {
                        title: {
                            display: true,
                            text: title
                        },
                        legend: {
                            position: 'top'
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: {
                                display: true,
                                text: 'Memory Usage (MB)'
                            }
                        }
                    }
                }
            });
        }

        // Initialize all charts when page loads
        document.addEventListener('DOMContentLoaded', function() {
            #{chart_init_code}
        });
      JS
    end

    # Generate HTML for single benchmark results (not multi-version)
    def generate_single_benchmark_html(results)
      @single_chart_initializers = []

      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>SerialBench - Performance Report</title>
            <link rel="stylesheet" href="../assets/css/benchmark_report.css">
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>SerialBench - Performance Report</h1>
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

                #{generate_single_parsing_section(results)}
                #{generate_single_generation_section(results)}
                #{generate_single_streaming_section(results)}
                #{generate_single_memory_section(results)}
                #{generate_summary_section(results)}
            </div>

            <script>
                #{generate_single_benchmark_javascript}
            </script>
        </body>
        </html>
      HTML
    end

    def generate_single_parsing_section(results)
      parsing_data = results[:parsing]
      return '<div id="parsing" class="section active"><p>No parsing data available</p></div>' unless parsing_data

      content = '<div id="parsing" class="section active">'
      content += '<h2>Parsing Performance</h2>'

      %i[small medium large].each do |size|
        next unless parsing_data[size]

        content += "<h3>#{size.capitalize} Files</h3>"
        content += '<div class="charts-grid">'

        parsing_data[size].each do |format, format_data|
          chart_id = "parsing_#{size}_#{format}"
          content += generate_single_performance_chart(chart_id, "#{format.upcase} Parsing (#{size})", format_data,
                                                       'iterations_per_second')
        end

        content += '</div>'
      end

      content += '</div>'
    end

    def generate_single_generation_section(results)
      generation_data = results[:generation]
      return '<div id="generation" class="section"><p>No generation data available</p></div>' unless generation_data

      content = '<div id="generation" class="section">'
      content += '<h2>Generation Performance</h2>'

      %i[small medium large].each do |size|
        next unless generation_data[size]

        content += "<h3>#{size.capitalize} Files</h3>"
        content += '<div class="charts-grid">'

        generation_data[size].each do |format, format_data|
          chart_id = "generation_#{size}_#{format}"
          content += generate_single_performance_chart(chart_id, "#{format.upcase} Generation (#{size})", format_data,
                                                       'iterations_per_second')
        end

        content += '</div>'
      end

      content += '</div>'
    end

    def generate_single_streaming_section(results)
      streaming_data = results[:streaming]
      return '<div id="streaming" class="section"><p>No streaming data available</p></div>' unless streaming_data

      content = '<div id="streaming" class="section">'
      content += '<h2>Streaming Performance</h2>'

      %i[small medium large].each do |size|
        next unless streaming_data[size]

        content += "<h3>#{size.capitalize} Files</h3>"
        content += '<div class="charts-grid">'

        streaming_data[size].each do |format, format_data|
          chart_id = "streaming_#{size}_#{format}"
          content += generate_single_performance_chart(chart_id, "#{format.upcase} Streaming (#{size})", format_data,
                                                       'iterations_per_second')
        end

        content += '</div>'
      end

      content += '</div>'
    end

    def generate_single_memory_section(results)
      memory_data = results[:memory_usage]
      return '<div id="memory" class="section"><p>No memory data available</p></div>' unless memory_data

      content = '<div id="memory" class="section">'
      content += '<h2>Memory Usage</h2>'

      %i[small medium large].each do |size|
        next unless memory_data[size]

        content += "<h3>#{size.capitalize} Files</h3>"
        content += '<div class="charts-grid">'

        memory_data[size].each do |format, format_data|
          chart_id = "memory_#{size}_#{format}"
          content += generate_single_memory_chart(chart_id, "#{format.upcase} Memory Usage (#{size})", format_data)
        end

        content += '</div>'
      end

      content += '</div>'
    end

    def generate_summary_section(results)
      content = '<div id="summary" class="section">'
      content += '<h2>Performance Summary</h2>'
      content += '<div class="summary-grid">'

      # Generate key findings
      content += '<div class="summary-card">'
      content += '<h3>Key Findings</h3>'
      content += generate_key_findings(results)
      content += '</div>'

      # Generate recommendations
      content += '<div class="summary-card">'
      content += '<h3>Recommendations</h3>'
      content += generate_recommendations(results)
      content += '</div>'

      content += '</div></div>'
    end

    def generate_single_performance_chart(chart_id, title, data, metric)
      @single_chart_initializers << "createSinglePerformanceChart('#{chart_id}', '#{title}', #{data.to_json}, '#{metric}');"

      <<~CHART
        <div class="chart-container">
            <h4>#{title}</h4>
            <canvas id="#{chart_id}" width="400" height="300"></canvas>
        </div>
      CHART
    end

    def generate_single_memory_chart(chart_id, title, data)
      @single_chart_initializers << "createSingleMemoryChart('#{chart_id}', '#{title}', #{data.to_json});"

      <<~CHART
        <div class="chart-container">
            <h4>#{title}</h4>
            <canvas id="#{chart_id}" width="400" height="300"></canvas>
        </div>
      CHART
    end

    def generate_single_benchmark_javascript
      chart_init_code = @single_chart_initializers ? @single_chart_initializers.join("\n        ") : ''

      <<~JS
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

        function createSinglePerformanceChart(canvasId, title, data, metric) {
            const ctx = document.getElementById(canvasId).getContext('2d');

            const serializers = Object.keys(data);
            const values = serializers.map(serializer => {
                const serializerData = data[serializer];
                return serializerData[metric] || 0;
            });

            const colors = serializers.map((_, index) => `hsl(${index * 60}, 70%, 50%)`);

            new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: serializers,
                    datasets: [{
                        label: metric === 'iterations_per_second' ? 'Operations/Second' : 'Time (ms)',
                        data: values,
                        backgroundColor: colors,
                        borderColor: colors.map(color => color.replace('50%', '40%')),
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        title: {
                            display: true,
                            text: title
                        },
                        legend: {
                            display: false
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: {
                                display: true,
                                text: metric === 'iterations_per_second' ? 'Operations/Second' : 'Time (ms)'
                            }
                        }
                    }
                }
            });
        }

        function createSingleMemoryChart(canvasId, title, data) {
            const ctx = document.getElementById(canvasId).getContext('2d');

            const serializers = Object.keys(data);
            const values = serializers.map(serializer => {
                const serializerData = data[serializer];
                return serializerData.allocated_memory ? (serializerData.allocated_memory / 1024 / 1024) : 0;
            });

            const colors = serializers.map((_, index) => `hsl(${index * 60}, 70%, 50%)`);

            new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: serializers,
                    datasets: [{
                        label: 'Memory Usage (MB)',
                        data: values,
                        backgroundColor: colors,
                        borderColor: colors.map(color => color.replace('50%', '40%')),
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        title: {
                            display: true,
                            text: title
                        },
                        legend: {
                            display: false
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: {
                                display: true,
                                text: 'Memory Usage (MB)'
                            }
                        }
                    }
                }
            });
        }

        document.addEventListener('DOMContentLoaded', function() {
            #{chart_init_code}
        });
      JS
    end

    def generate_key_findings(results)
      findings = []

      # Analyze parsing results
      if results[:parsing]
        fastest_parser = find_fastest_serializer(results[:parsing])
        if fastest_parser
          findings << "<li><strong>#{fastest_parser[:name].capitalize}</strong> demonstrates superior parsing performance with #{fastest_parser[:performance]} average across all test sizes</li>"
        end
      end

      # Analyze generation results
      if results[:generation]
        fastest_gen = find_fastest_serializer(results[:generation])
        if fastest_gen
          findings << "<li><strong>#{fastest_gen[:name].capitalize}</strong> excels in generation performance with #{fastest_gen[:performance]}</li>"
        end
      end

      # Analyze memory usage
      if results[:memory_usage]
        most_efficient = find_most_memory_efficient_serializer(results[:memory_usage])
        if most_efficient
          findings << "<li><strong>#{most_efficient[:name].capitalize}</strong> shows the best memory efficiency, using #{most_efficient[:memory]} on average</li>"
        end
      end

      findings.empty? ? '<p>Analysis pending - benchmark data processing in progress.</p>' : "<ul>#{findings.join("\n")}</ul>"
    end

    def generate_recommendations(results)
      recommendations = []

      # Performance recommendations
      if results[:parsing]
        fastest = find_fastest_serializer(results[:parsing])
        if fastest
          recommendations << "<li><strong>For high-performance applications:</strong> Use #{fastest[:name].capitalize} for optimal parsing speed</li>"
        end
      end

      # Memory recommendations
      if results[:memory_usage]
        most_efficient = find_most_memory_efficient_serializer(results[:memory_usage])
        if most_efficient
          recommendations << "<li><strong>For memory-constrained environments:</strong> #{most_efficient[:name].capitalize} provides the best memory efficiency</li>"
        end
      end

      # General recommendations
      recommendations << '<li><strong>For built-in support:</strong> JSON and REXML require no additional dependencies</li>'
      recommendations << '<li><strong>For streaming large files:</strong> Consider SAX/streaming parsers when available</li>'

      recommendations.empty? ? '<p>Recommendations require complete benchmark data.</p>' : "<ul>#{recommendations.join("\n")}</ul>"
    end

    def find_fastest_serializer(category_results)
      return nil unless category_results && !category_results.empty?

      serializer_averages = {}

      category_results.each do |size, size_data|
        size_data.each do |format, format_data|
          format_data.each do |serializer, data|
            next if data[:error] || !data[:iterations_per_second]

            key = "#{format}/#{serializer}"
            serializer_averages[key] ||= []
            serializer_averages[key] << data[:iterations_per_second]
          end
        end
      end

      return nil if serializer_averages.empty?

      fastest = serializer_averages.max_by { |serializer, values| values.sum / values.length.to_f }
      avg_performance = fastest[1].sum / fastest[1].length.to_f

      {
        name: fastest[0],
        performance: "#{avg_performance.round(2)} ops/sec"
      }
    end

    def find_most_memory_efficient_serializer(memory_results)
      return nil unless memory_results && !memory_results.empty?

      serializer_averages = {}

      memory_results.each do |size, size_data|
        size_data.each do |format, format_data|
          format_data.each do |serializer, data|
            next if data[:error] || !data[:allocated_memory]

            key = "#{format}/#{serializer}"
            serializer_averages[key] ||= []
            serializer_averages[key] << data[:allocated_memory]
          end
        end
      end

      return nil if serializer_averages.empty?

      most_efficient = serializer_averages.min_by { |serializer, values| values.sum / values.length.to_f }
      avg_memory = most_efficient[1].sum / most_efficient[1].length.to_f

      {
        name: most_efficient[0],
        memory: "#{(avg_memory / 1024.0 / 1024.0).round(2)}MB"
      }
    end

    def setup_directories
      [@output_dir, @charts_dir, @reports_dir, @assets_dir].each do |dir|
        FileUtils.mkdir_p(dir)
      end
      FileUtils.mkdir_p(File.join(@assets_dir, 'css'))
    end

    def generate_css
      css_content = <<~CSS
        /* SerialBench Report Styles */
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
