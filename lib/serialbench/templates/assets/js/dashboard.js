/**
 * Modern Dashboard for SerialBench Format-Based Reports
 * Features: Tag-based filtering, theme management, responsive charts
 */

class SerialBenchDashboard {
    constructor() {
        // Handle the new nested data structure
        const rawData = window.benchmarkData || {};
        this.data = {
            combined_results: rawData.combined_results || {},
            environments: rawData.environments || {},
            metadata: rawData.metadata || {}
        };
        this.charts = new Map();
        this.filters = {
            platforms: new Set(),
            rubyTypes: new Set(['ruby']), // Default to ruby, will add jruby later
            rubyVersions: new Set(),
            format: 'xml'
        };

        this.theme = this.getStoredTheme() || this.getSystemTheme();
        this.isInitialized = false;

        this.init();
    }

    async init() {
        try {
            console.log('🚀 Initializing SerialBench Dashboard...');

            // Apply theme immediately
            this.applyTheme(this.theme);

            // Initialize components
            this.setupThemeToggle();
            this.initializeFilters();
            this.setupEventListeners();
            this.createCharts();
            this.updateSummary();
            this.updateEnvironmentInfo();

            // Set initial filter states
            this.setDefaultFilters();
            this.applyFilters();

            this.isInitialized = true;
            console.log('✅ Dashboard initialized successfully');

        } catch (error) {
            console.error('❌ Dashboard initialization failed:', error);
            this.showError('Failed to initialize dashboard');
        }
    }

    // Theme Management
    getSystemTheme() {
        return window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
    }

    getStoredTheme() {
        return localStorage.getItem('serialbench-theme');
    }

    applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        this.theme = theme;
        localStorage.setItem('serialbench-theme', theme);

        // Update theme toggle icon
        const themeToggle = document.querySelector('.theme-toggle');
        if (themeToggle) {
            const icon = themeToggle.querySelector('svg');
            if (icon) {
                icon.innerHTML = theme === 'light'
                    ? '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>' // moon
                    : '<circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>'; // sun
            }
        }
    }

    setupThemeToggle() {
        const themeToggle = document.querySelector('.theme-toggle');
        if (themeToggle) {
            themeToggle.addEventListener('click', () => {
                const newTheme = this.theme === 'dark' ? 'light' : 'dark';
                this.applyTheme(newTheme);

                // Update charts with new theme
                if (this.isInitialized) {
                    this.updateChartsTheme();
                }
            });
        }
    }

    // Filter Management
    initializeFilters() {
        this.populateFilterOptions();
        this.setupFilterEventListeners();
    }

    populateFilterOptions() {
        // Extract available platforms from data
        const platforms = new Set();
        const rubyVersions = new Set();

        if (this.data.environments) {
            Object.values(this.data.environments).forEach(env => {
                // Use os-arch combination instead of ruby_platform
                const platformKey = `${env.os}-${env.arch}`;
                platforms.add(platformKey);
                rubyVersions.add(env.ruby_version);
            });
        }

        // Populate platform filter
        const platformSelect = document.getElementById('platform-filter');
        if (platformSelect) {
            platformSelect.innerHTML = '<option value="">All Platforms</option>';
            Array.from(platforms).sort().forEach(platform => {
                const option = document.createElement('option');
                option.value = platform;
                option.textContent = platform;
                platformSelect.appendChild(option);
            });
        }

        // Populate Ruby version filter
        const versionSelect = document.getElementById('ruby-version-filter');
        if (versionSelect) {
            versionSelect.innerHTML = '<option value="">All Versions</option>';
            Array.from(rubyVersions).sort().forEach(version => {
                const option = document.createElement('option');
                option.value = version;
                option.textContent = `Ruby ${version}`;
                versionSelect.appendChild(option);
            });
        }

        // Ruby type filter (for future JRuby support)
        const typeSelect = document.getElementById('ruby-type-filter');
        if (typeSelect) {
            typeSelect.innerHTML = `
                <option value="">All Types</option>
                <option value="ruby" selected>Ruby</option>
                <option value="jruby" disabled>JRuby (Coming Soon)</option>
            `;
        }
    }


    setupFilterEventListeners() {
        // Platform filter
        const platformSelect = document.getElementById('platform-filter');
        if (platformSelect) {
            platformSelect.addEventListener('change', (e) => {
                if (e.target.value) {
                    this.filters.platforms = new Set([e.target.value]);
                } else {
                    this.filters.platforms.clear();
                }
                this.applyFilters();
            });
        }

        // Ruby version filter
        const versionSelect = document.getElementById('ruby-version-filter');
        if (versionSelect) {
            versionSelect.addEventListener('change', (e) => {
                if (e.target.value) {
                    this.filters.rubyVersions = new Set([e.target.value]);
                } else {
                    this.filters.rubyVersions.clear();
                }
                this.applyFilters();
            });
        }

        // Ruby type filter
        const typeSelect = document.getElementById('ruby-type-filter');
        if (typeSelect) {
            typeSelect.addEventListener('change', (e) => {
                if (e.target.value) {
                    this.filters.rubyTypes = new Set([e.target.value]);
                } else {
                    this.filters.rubyTypes = new Set(['ruby']); // Default to ruby
                }
                this.applyFilters();
            });
        }

        // Format tabs
        document.querySelectorAll('.format-tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                e.preventDefault();
                const format = e.target.dataset.format;
                this.setActiveFormat(format);
                this.applyFilters();
            });
        });
    }

    setDefaultFilters() {
        // Set all platforms and versions by default
        if (this.data.environments) {
            Object.values(this.data.environments).forEach(env => {
                // Use os-arch combination instead of ruby_platform
                const platformKey = `${env.os}-${env.arch}`;
                this.filters.platforms.add(platformKey);
                this.filters.rubyVersions.add(env.ruby_version);
            });
        }

        console.log('🔧 Default filters set:', {
            platforms: Array.from(this.filters.platforms),
            rubyVersions: Array.from(this.filters.rubyVersions),
            environmentCount: Object.keys(this.data.environments || {}).length
        });
    }

    setActiveFormat(format) {
        this.filters.format = format;

        // Update active tab
        document.querySelectorAll('.format-tab').forEach(tab => {
            tab.classList.remove('active');
        });

        const activeTab = document.querySelector(`[data-format="${format}"]`);
        if (activeTab) {
            activeTab.classList.add('active');
        }
    }

    applyFilters() {
        if (!this.isInitialized) return;

        console.log('🔍 Applying filters:', this.filters);

        // Update charts with filtered data
        this.updateCharts();
        this.updateSummary();
        this.updateEnvironmentInfo();

        // Update URL to reflect current state
        this.updateURL();
    }

    // Chart Management
    createCharts() {
        const operations = ['parsing', 'generation', 'memory', 'streaming'];

        operations.forEach(operation => {
            this.createChart(operation);
        });
    }

    createChart(operation) {
        const canvas = document.getElementById(`chart-${operation}`);
        if (!canvas) {
            console.warn(`Canvas not found for operation: ${operation}`);
            return;
        }

        // Clear any existing error message and show canvas
        this.clearChartError(canvas);

        const ctx = canvas.getContext('2d');
        const data = this.getFilteredChartData(operation);

        if (!data || data.datasets.length === 0) {
            this.showChartError(canvas, `No data available for ${operation}`);
            return;
        }

        try {
            const chart = new Chart(ctx, {
                type: 'bar',
                data: data,
                options: this.getChartOptions(operation)
            });

            this.charts.set(operation, chart);
            console.log(`📊 Created chart for ${operation}`);

        } catch (error) {
            console.error(`Failed to create chart for ${operation}:`, error);
            this.showChartError(canvas, `Failed to load ${operation} chart`);
        }
    }

    getFilteredChartData(operation) {
        const format = this.filters.format;

        if (!this.data.combined_results || !this.data.combined_results[operation]) {
            return { labels: [], datasets: [] };
        }

        const operationData = this.data.combined_results[operation];

        // Combine data from all sizes for this operation and format
        const combinedData = {};

        ['small', 'medium', 'large'].forEach(size => {
            if (operationData[size] && operationData[size][format]) {
                const sizeData = operationData[size][format];

                Object.keys(sizeData).forEach(serializer => {
                    if (!combinedData[serializer]) {
                        combinedData[serializer] = {};
                    }

                    Object.keys(sizeData[serializer]).forEach(envKey => {
                        const envData = sizeData[serializer][envKey];
                        const env = this.data.environments[envKey];

                        if (this.shouldIncludeEnvironment(env)) {
                            const label = `${env.ruby_version} (${size})`;
                            combinedData[serializer][label] = envData;
                        }
                    });
                });
            }
        });

        return this.formatChartData(combinedData, operation);
    }

    shouldIncludeEnvironment(env) {
        if (!env) return false;

        // Use os-arch combination for platform matching
        const platformKey = `${env.os}-${env.arch}`;
        const platformMatch = this.filters.platforms.size === 0 ||
                             this.filters.platforms.has(platformKey);
        const versionMatch = this.filters.rubyVersions.size === 0 ||
                            this.filters.rubyVersions.has(env.ruby_version);

        return platformMatch && versionMatch;
    }

    formatChartData(data, operation) {
        const serializers = Object.keys(data);
        if (serializers.length === 0) {
            return { labels: [], datasets: [] };
        }

        // Get all unique labels
        const allLabels = new Set();
        serializers.forEach(serializer => {
            Object.keys(data[serializer]).forEach(label => allLabels.add(label));
        });

        const labels = Array.from(allLabels).sort();

        // Create datasets
        const datasets = serializers.map((serializer, index) => {
            const serializerData = data[serializer];

            const values = labels.map(label => {
                const envData = serializerData[label];
                if (!envData) return 0;

                if (operation === 'memory') {
                    return envData.allocated_memory ? envData.allocated_memory / 1024 / 1024 : 0;
                } else {
                    return envData.iterations_per_second || 0;
                }
            });

            return {
                label: this.formatSerializerName(serializer),
                data: values,
                backgroundColor: this.getSerializerColor(serializer, 0.8),
                borderColor: this.getSerializerColor(serializer, 1),
                borderWidth: 2,
                borderRadius: 4,
                borderSkipped: false,
            };
        });

        return { labels, datasets };
    }

    formatSerializerName(serializer) {
        const nameMap = {
            'rexml': 'REXML',
            'ox': 'Ox',
            'nokogiri': 'Nokogiri',
            'json': 'JSON',
            'oj': 'Oj',
            'rapidjson': 'RapidJSON',
            'yajl': 'YAJL',
            'psych': 'Psych',
            'syck': 'Syck',
            'toml-rb': 'TOML-RB',
            'tomlib': 'Tomlib'
        };
        return nameMap[serializer] || serializer.toUpperCase();
    }

    getSerializerColor(serializer, alpha = 1) {
        const colors = {
            'rexml': `rgba(239, 68, 68, ${alpha})`,    // red
            'ox': `rgba(249, 115, 22, ${alpha})`,      // orange
            'nokogiri': `rgba(34, 197, 94, ${alpha})`, // green
            'json': `rgba(59, 130, 246, ${alpha})`,    // blue
            'oj': `rgba(147, 51, 234, ${alpha})`,      // purple
            'rapidjson': `rgba(236, 72, 153, ${alpha})`, // pink
            'yajl': `rgba(14, 165, 233, ${alpha})`,    // sky
            'psych': `rgba(16, 185, 129, ${alpha})`,   // emerald
            'syck': `rgba(245, 158, 11, ${alpha})`,    // amber
            'toml-rb': `rgba(168, 85, 247, ${alpha})`, // violet
            'tomlib': `rgba(6, 182, 212, ${alpha})`    // cyan
        };

        return colors[serializer] || `rgba(107, 114, 128, ${alpha})`;
    }

    getChartOptions(operation) {
        const isDark = this.theme === 'dark';
        const textColor = isDark ? '#CBD5E1' : '#334155';
        const gridColor = isDark ? '#475569' : '#E2E8F0';

        return {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                intersect: false,
                mode: 'index'
            },
            plugins: {
                title: {
                    display: true,
                    text: this.getChartTitle(operation),
                    color: textColor,
                    font: {
                        size: 16,
                        weight: 'bold'
                    },
                    padding: 20
                },
                legend: {
                    position: 'top',
                    labels: {
                        color: textColor,
                        usePointStyle: true,
                        padding: 15
                    }
                },
                tooltip: {
                    backgroundColor: isDark ? '#1E293B' : '#FFFFFF',
                    titleColor: textColor,
                    bodyColor: textColor,
                    borderColor: isDark ? '#475569' : '#E2E8F0',
                    borderWidth: 1,
                    cornerRadius: 8,
                    displayColors: true,
                    callbacks: {
                        label: (context) => {
                            const value = context.parsed.y;
                            const unit = operation === 'memory' ? 'MB' : 'ops/sec';
                            return `${context.dataset.label}: ${value.toLocaleString()} ${unit}`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: {
                        color: gridColor,
                        drawBorder: false
                    },
                    ticks: {
                        color: textColor,
                        maxRotation: 45
                    }
                },
                y: {
                    beginAtZero: true,
                    grid: {
                        color: gridColor,
                        drawBorder: false
                    },
                    ticks: {
                        color: textColor,
                        callback: function(value) {
                            if (operation === 'memory') {
                                return value.toLocaleString() + ' MB';
                            } else {
                                return value.toLocaleString() + ' ops/sec';
                            }
                        }
                    },
                    title: {
                        display: true,
                        text: operation === 'memory' ? 'Memory Usage (MB)' : 'Operations per Second',
                        color: textColor,
                        font: {
                            weight: 'bold'
                        }
                    }
                }
            },
            animation: {
                duration: 750,
                easing: 'easeInOutQuart'
            }
        };
    }

    getChartTitle(operation) {
        const format = this.filters.format.toUpperCase();
        const titles = {
            'parsing': `${format} Parsing Performance`,
            'generation': `${format} Generation Performance`,
            'memory': `${format} Memory Usage`,
            'streaming': `${format} Streaming Performance`
        };
        return titles[operation] || `${format} ${operation}`;
    }

    updateCharts() {
        const operations = ['parsing', 'generation', 'memory', 'streaming'];

        operations.forEach(operation => {
            try {
                console.log(`🔄 Updating chart for ${operation}...`);
                const chart = this.charts.get(operation);
                const newData = this.getFilteredChartData(operation);
                console.log(`📊 Data for ${operation}:`, newData.datasets.length, 'datasets');

                if (newData.datasets.length === 0) {
                    console.log(`❌ No data for ${operation}, destroying chart`);
                    // Destroy existing chart and show error
                    if (chart) {
                        chart.destroy();
                        this.charts.delete(operation);
                    }
                    const canvas = document.getElementById(`chart-${operation}`);
                    if (canvas) {
                        this.showChartError(canvas, `No data available for ${operation}`);
                    }
                    return;
                }

                // Check if chart exists and canvas is valid
                if (!chart || !chart.canvas || !chart.canvas.getContext) {
                    console.log(`🔧 Recreating chart for ${operation}`);
                    // Recreate chart if it was destroyed or canvas was replaced
                    this.createChart(operation);
                    return;
                }

                console.log(`✅ Updating existing chart for ${operation}`);
                chart.data = newData;
                chart.options = this.getChartOptions(operation);
                chart.update('active');

            } catch (error) {
                console.error(`❌ Error updating chart for ${operation}:`, error);
                // Try to recreate the chart
                try {
                    this.createChart(operation);
                } catch (recreateError) {
                    console.error(`❌ Failed to recreate chart for ${operation}:`, recreateError);
                }
            }
        });
    }

    updateChartsTheme() {
        this.charts.forEach((chart, operation) => {
            chart.options = this.getChartOptions(operation);
            chart.update('none');
        });
    }

    clearChartError(canvas) {
        const container = canvas.parentElement;

        // Remove any existing error message
        const existingError = container.querySelector('.chart-error');
        if (existingError) {
            existingError.remove();
        }

        // Show the canvas
        canvas.style.display = 'block';
    }

    showChartError(canvas, message) {
        const container = canvas.parentElement;
        const canvasId = canvas.id;

        // Clear any existing error message
        const existingError = container.querySelector('.chart-error');
        if (existingError) {
            existingError.remove();
        }

        // Hide the canvas and show error message
        canvas.style.display = 'none';

        const errorDiv = document.createElement('div');
        errorDiv.className = 'chart-error';
        errorDiv.innerHTML = `
            <svg width="24" height="24" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="15" y1="9" x2="9" y2="15"></line>
                <line x1="9" y1="9" x2="15" y2="15"></line>
            </svg>
            <span>${message}</span>
        `;

        container.appendChild(errorDiv);
    }

    // Summary and Environment Updates
    updateSummary() {
        // This would analyze the current filtered data and update performance summaries
        console.log('📈 Updating performance summary...');
    }

    updateEnvironmentInfo() {
        const container = document.getElementById('environment-info');
        if (!container || !this.data.environments) return;

        // Show all environments, but apply platform and version filters only (not format)
        const filteredEnvs = Object.entries(this.data.environments)
            .filter(([key, env]) => {
                // Use os-arch combination for platform matching
                const platformKey = `${env.os}-${env.arch}`;
                const platformMatch = this.filters.platforms.size === 0 ||
                                     this.filters.platforms.has(platformKey);
                const versionMatch = this.filters.rubyVersions.size === 0 ||
                                    this.filters.rubyVersions.has(env.ruby_version);
                return platformMatch && versionMatch;
            });

        if (filteredEnvs.length === 0) {
            container.innerHTML = '<p class="text-muted">No environments match current filters</p>';
            return;
        }

        container.innerHTML = filteredEnvs.map(([key, env]) => `
            <div class="environment-card fade-in-up">
                <h3 class="environment-card-title">
                    Ruby ${env.ruby_version} on ${env.os}-${env.arch}
                </h3>
                <p><strong>Source:</strong> ${env.source_file ? env.source_file.split('/').pop() : 'Unknown'}</p>
                <p><strong>Timestamp:</strong> ${new Date(env.timestamp).toLocaleString()}</p>
                ${this.generateSerializerVersions(env.environment)}
            </div>
        `).join('');
    }

    generateSerializerVersions(environment) {
        if (!environment || !environment.serializer_versions) {
            return '';
        }

        const versions = Object.entries(environment.serializer_versions)
            .map(([name, version]) => `<li><strong>${name}:</strong> ${version}</li>`)
            .join('');

        return `
            <div class="serializer-versions">
                <h4>Serializer Versions:</h4>
                <ul style="margin: 0.5rem 0; padding-left: 1.5rem; color: var(--text-muted);">${versions}</ul>
            </div>
        `;
    }

    // Event Listeners
    setupEventListeners() {
        // Handle window resize
        window.addEventListener('resize', _.debounce(() => {
            this.charts.forEach(chart => chart.resize());
        }, 250));

        // Handle system theme changes
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
            if (!localStorage.getItem('serialbench-theme')) {
                this.applyTheme(e.matches ? 'dark' : 'light');
                this.updateChartsTheme();
            }
        });
    }

    // URL Management
    updateURL() {
        const params = new URLSearchParams();

        if (this.filters.platforms.size > 0) {
            params.set('platforms', Array.from(this.filters.platforms).join(','));
        }
        if (this.filters.rubyVersions.size > 0) {
            params.set('versions', Array.from(this.filters.rubyVersions).join(','));
        }
        if (this.filters.format !== 'xml') {
            params.set('format', this.filters.format);
        }

        const newURL = `${window.location.pathname}${params.toString() ? '?' + params.toString() : ''}`;
        window.history.replaceState({}, '', newURL);
    }

    loadFromURL() {
        const params = new URLSearchParams(window.location.search);

        if (params.has('platforms')) {
            this.filters.platforms = new Set(params.get('platforms').split(','));
        }
        if (params.has('versions')) {
            this.filters.rubyVersions = new Set(params.get('versions').split(','));
        }
        if (params.has('format')) {
            this.filters.format = params.get('format');
        }
    }

    // Utility Methods
    showError(message) {
        console.error('Dashboard Error:', message);
        // Could show a toast notification here
    }

    // Public API
    getFilterState() {
        return { ...this.filters };
    }

    setFilters(newFilters) {
        Object.assign(this.filters, newFilters);
        this.applyFilters();
    }

    exportData() {
        const filteredData = this.getFilteredData();
        const blob = new Blob([JSON.stringify(filteredData, null, 2)], {
            type: 'application/json'
        });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `serialbench-${this.filters.format}-${Date.now()}.json`;
        a.click();
        URL.revokeObjectURL(url);
    }

    getFilteredData() {
        // Return filtered dataset for export
        return {
            filters: this.filters,
            timestamp: new Date().toISOString(),
            data: this.data
        };
    }
}

// Utility function for debouncing (simple implementation)
const _ = {
    debounce: (func, wait) => {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
};

// Initialize dashboard when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    console.log('🎯 DOM loaded, checking for benchmark data...');

    if (!window.benchmarkData) {
        console.error('❌ No benchmark data found');
        return;
    }

    console.log('📊 Benchmark data found, initializing dashboard...');
    window.serialBenchDashboard = new SerialBenchDashboard();
});

// Export for external use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = SerialBenchDashboard;
}
