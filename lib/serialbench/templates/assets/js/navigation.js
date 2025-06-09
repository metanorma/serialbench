// Navigation and UI interaction functions for Serialbench reports

/**
 * Show a specific section and update navigation state
 */
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
    const targetSection = document.getElementById(sectionName);
    if (targetSection) {
        targetSection.classList.add('active');
    }

    // Add active class to clicked button
    if (event && event.target) {
        event.target.classList.add('active');
    }

    // Smooth scroll to top of section
    if (targetSection) {
        targetSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}

/**
 * Initialize navigation event listeners
 */
function initializeNavigation() {
    // Add click event listeners to navigation buttons
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            const sectionName = this.getAttribute('data-section') ||
                               this.textContent.toLowerCase().replace(/\s+/g, '').replace('performance', '');
            showSection(sectionName);
        });
    });

    // Add keyboard navigation support
    document.addEventListener('keydown', function(e) {
        if (e.altKey) {
            const keyMap = {
                '1': 'parsing',
                '2': 'generation',
                '3': 'streaming',
                '4': 'memory',
                '5': 'summary',
                '6': 'environments'
            };

            if (keyMap[e.key]) {
                e.preventDefault();
                showSection(keyMap[e.key]);

                // Update button state
                document.querySelectorAll('.nav-btn').forEach(btn => {
                    btn.classList.remove('active');
                    if (btn.textContent.toLowerCase().includes(keyMap[e.key]) ||
                        (keyMap[e.key] === 'parsing' && btn.textContent.toLowerCase().includes('parsing')) ||
                        (keyMap[e.key] === 'generation' && btn.textContent.toLowerCase().includes('generation')) ||
                        (keyMap[e.key] === 'streaming' && btn.textContent.toLowerCase().includes('streaming')) ||
                        (keyMap[e.key] === 'memory' && btn.textContent.toLowerCase().includes('memory')) ||
                        (keyMap[e.key] === 'summary' && btn.textContent.toLowerCase().includes('summary')) ||
                        (keyMap[e.key] === 'environments' && btn.textContent.toLowerCase().includes('environment'))) {
                        btn.classList.add('active');
                    }
                });
            }
        }
    });
}

/**
 * Add loading states to charts
 */
function addChartLoadingStates() {
    document.querySelectorAll('.chart-container canvas').forEach(canvas => {
        const container = canvas.closest('.chart-container');
        if (container) {
            container.classList.add('loading');

            // Remove loading state after chart is rendered
            setTimeout(() => {
                container.classList.remove('loading');
            }, 1000);
        }
    });
}

/**
 * Add tooltips to navigation buttons
 */
function addNavigationTooltips() {
    const tooltips = {
        'parsing': 'View parsing performance benchmarks (Alt+1)',
        'generation': 'View generation performance benchmarks (Alt+2)',
        'streaming': 'View streaming performance benchmarks (Alt+3)',
        'memory': 'View memory usage analysis (Alt+4)',
        'summary': 'View performance summary and recommendations (Alt+5)',
        'environments': 'View environment and version details (Alt+6)'
    };

    document.querySelectorAll('.nav-btn').forEach(btn => {
        const text = btn.textContent.toLowerCase();
        for (const [key, tooltip] of Object.entries(tooltips)) {
            if (text.includes(key) || (key === 'environments' && text.includes('environment'))) {
                btn.title = tooltip;
                break;
            }
        }
    });
}

/**
 * Initialize all UI enhancements
 */
function initializeUI() {
    // Wait for DOM to be fully loaded
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            initializeNavigation();
            addNavigationTooltips();
            addChartLoadingStates();
        });
    } else {
        initializeNavigation();
        addNavigationTooltips();
        addChartLoadingStates();
    }
}

// Auto-initialize when script loads
initializeUI();
