// Chart.js helper functions for Serialbench reports

/**
 * Check if Chart.js is loaded
 */
function isChartJsLoaded() {
    return typeof Chart !== 'undefined';
}

/**
 * Create a performance chart for single benchmark results
 */
function createSinglePerformanceChart(canvasId, title, data, metric) {
    if (!isChartJsLoaded()) {
        console.error('Chart.js is not loaded');
        return;
    }

    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.warn(`Canvas element with id '${canvasId}' not found`);
        return;
    }

    const ctx = canvas.getContext('2d');

    const serializers = Object.keys(data);
    const values = serializers.map(serializer => {
        const serializerData = data[serializer];
        return serializerData[metric] || 0;
    });

    const colors = serializers.map((_, index) => `hsl(${index * 60}, 70%, 50%)`);

    try {
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
        console.log(`Successfully created chart: ${canvasId}`);
    } catch (error) {
        console.error(`Error creating chart ${canvasId}:`, error);
    }
}

/**
 * Create a memory chart for single benchmark results
 */
function createSingleMemoryChart(canvasId, title, data) {
    if (!isChartJsLoaded()) {
        console.error('Chart.js is not loaded');
        return;
    }

    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.warn(`Canvas element with id '${canvasId}' not found`);
        return;
    }

    const ctx = canvas.getContext('2d');

    const serializers = Object.keys(data);
    const values = serializers.map(serializer => {
        const serializerData = data[serializer];
        return serializerData.allocated_memory ? (serializerData.allocated_memory / 1024 / 1024) : 0;
    });

    const colors = serializers.map((_, index) => `hsl(${index * 60}, 70%, 50%)`);

    try {
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
        console.log(`Successfully created memory chart: ${canvasId}`);
    } catch (error) {
        console.error(`Error creating memory chart ${canvasId}:`, error);
    }
}

/**
 * Create a performance chart for multi-version comparison
 */
function createPerformanceChart(canvasId, title, data, metric, environments) {
    console.log(`🎨 createPerformanceChart called for ${canvasId}`);
    console.log(`📊 Chart.js available:`, typeof Chart !== 'undefined');
    console.log(`📊 Chart.js object:`, Chart);

    if (!isChartJsLoaded()) {
        console.error('❌ Chart.js is not loaded');
        return;
    }

    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.warn(`⚠️ Canvas element with id '${canvasId}' not found`);
        return;
    }

    console.log(`✅ Canvas found:`, canvas);
    const ctx = canvas.getContext('2d');
    console.log(`✅ Context obtained:`, ctx);

    const serializers = Object.keys(data);
    if (serializers.length === 0) {
        console.warn(`⚠️ No data available for chart: ${canvasId}`);
        return;
    }

    console.log(`📈 Serializers:`, serializers);
    console.log(`🌍 Environments:`, environments);
    console.log(`📊 Raw data:`, data);

    // Get theme-aware colors
    const isDarkMode = document.documentElement.getAttribute('data-theme') === 'dark';
    const textColor = getComputedStyle(document.documentElement).getPropertyValue('--text-primary').trim() || (isDarkMode ? '#F8FAFC' : '#0F172A');
    const gridColor = getComputedStyle(document.documentElement).getPropertyValue('--border-primary').trim() || (isDarkMode ? '#475569' : '#E2E8F0');

    // High contrast color palette
    const colors = [
        '#F97316', '#3B82F6', '#10B981', '#EF4444', '#8B5CF6',
        '#F59E0B', '#EC4899', '#06B6D4', '#84CC16', '#6366F1'
    ];

    const datasets = serializers.map((serializer, index) => {
        const serializerData = data[serializer];
        console.log(`🔍 Processing serializer ${serializer}:`, serializerData);

        const values = environments.map(env => {
            const value = serializerData[env]?.iterations_per_second || 0;
            console.log(`  📊 ${env}: ${value}`);
            return value;
        });

        console.log(`📊 Values for ${serializer}:`, values);

        return {
            label: serializer,
            data: values,
            backgroundColor: colors[index % colors.length],
            borderColor: colors[index % colors.length],
            borderWidth: 2,
            borderRadius: 4,
            borderSkipped: false,
        };
    });

    // Convert environment names to readable Ruby versions
    const labels = environments.map(env => {
        const match = env.match(/(\d+_\d+_\d+)/);
        return match ? `Ruby ${match[1].replace(/_/g, '.')}` : env;
    });

    console.log(`🏷️ Chart labels:`, labels);
    console.log(`📊 Chart datasets:`, datasets);

    try {
        const chartConfig = {
            type: 'bar',
            data: {
                labels: labels,
                datasets: datasets
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: {
                        display: true,
                        text: title,
                        font: { size: 16, weight: 'bold' },
                        color: textColor
                    },
                    legend: {
                        position: 'top',
                        labels: {
                            usePointStyle: true,
                            padding: 20,
                            font: { size: 12 },
                            color: textColor
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Iterations per Second',
                            font: { size: 12, weight: 'bold' },
                            color: textColor
                        },
                        ticks: {
                            color: textColor
                        },
                        grid: {
                            color: gridColor
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Ruby Versions',
                            font: { size: 12, weight: 'bold' },
                            color: textColor
                        },
                        ticks: {
                            color: textColor
                        },
                        grid: {
                            display: false
                        }
                    }
                }
            }
        };

        console.log(`🎯 Creating chart with config:`, chartConfig);
        const chart = new Chart(ctx, chartConfig);
        console.log(`✅ Chart created successfully:`, chart);
        console.log(`✅ Successfully created performance chart: ${canvasId}`);
    } catch (error) {
        console.error(`❌ Error creating performance chart ${canvasId}:`, error);
        console.error(`❌ Error stack:`, error.stack);
    }
}

/**
 * Create a memory chart for multi-version comparison
 */
function createMemoryChart(canvasId, title, data, environments) {
    if (!isChartJsLoaded()) {
        console.error('Chart.js is not loaded');
        return;
    }

    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.warn(`Canvas element with id '${canvasId}' not found`);
        return;
    }

    const ctx = canvas.getContext('2d');

    const serializers = Object.keys(data);
    if (serializers.length === 0) {
        console.warn(`No data available for memory chart: ${canvasId}`);
        return;
    }

    // Get theme-aware colors
    const isDarkMode = document.documentElement.getAttribute('data-theme') === 'dark';
    const textColor = getComputedStyle(document.documentElement).getPropertyValue('--text-primary').trim() || (isDarkMode ? '#F8FAFC' : '#0F172A');
    const gridColor = getComputedStyle(document.documentElement).getPropertyValue('--border-primary').trim() || (isDarkMode ? '#475569' : '#E2E8F0');

    // High contrast color palette
    const colors = [
        '#F97316', '#3B82F6', '#10B981', '#EF4444', '#8B5CF6',
        '#F59E0B', '#EC4899', '#06B6D4', '#84CC16', '#6366F1'
    ];

    const datasets = serializers.map((serializer, index) => {
        const serializerData = data[serializer];
        const values = environments.map(env => {
            const envData = serializerData[env];
            return envData ? (envData.allocated_memory / 1024 / 1024) : 0; // Convert to MB
        });

        return {
            label: serializer,
            data: values,
            backgroundColor: colors[index % colors.length],
            borderColor: colors[index % colors.length],
            borderWidth: 2,
            borderRadius: 4,
            borderSkipped: false,
        };
    });

    // Convert environment names to readable Ruby versions
    const labels = environments.map(env => {
        const match = env.match(/(\d+_\d+_\d+)/);
        return match ? `Ruby ${match[1].replace(/_/g, '.')}` : env;
    });

    try {
        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: datasets
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: {
                        display: true,
                        text: title,
                        font: { size: 16, weight: 'bold' },
                        color: textColor
                    },
                    legend: {
                        position: 'top',
                        labels: {
                            usePointStyle: true,
                            padding: 20,
                            font: { size: 12 },
                            color: textColor
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Memory Usage (MB)',
                            font: { size: 12, weight: 'bold' },
                            color: textColor
                        },
                        ticks: {
                            color: textColor
                        },
                        grid: {
                            color: gridColor
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Ruby Versions',
                            font: { size: 12, weight: 'bold' },
                            color: textColor
                        },
                        ticks: {
                            color: textColor
                        },
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });
        console.log(`Successfully created memory chart: ${canvasId}`);
    } catch (error) {
        console.error(`Error creating memory chart ${canvasId}:`, error);
    }
}
