<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue';
import {
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  Legend,
  LinearScale,
  LogarithmicScale,
  Tooltip,
} from 'chart.js';
import type { Payload } from '../lib/dashboard';

Chart.register(BarController, BarElement, CategoryScale, LinearScale, LogarithmicScale, Tooltip, Legend);

const props = defineProps<{
  payload: Payload;
  op: string;
  format: string;
  sizes: string[];
  envKey: string;
  serializers: string[];
}>();

const canvas = ref<HTMLCanvasElement | null>(null);
let chart: Chart | null = null;

function cssVar(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

function ipsAt(serializer: string, size: string): number {
  const metric = props.payload.combined_results[props.op]?.[size]?.[props.format]?.[serializer]?.[props.envKey] as
    | { iterations_per_second: number }
    | undefined;
  return metric?.iterations_per_second ?? 0;
}

function orderedSerializers(): string[] {
  const anchor = props.sizes[props.sizes.length - 1] ?? 'small';
  return [...props.serializers].sort((a, b) => ipsAt(b, anchor) - ipsAt(a, anchor));
}

function build() {
  if (!canvas.value) return;
  chart?.destroy();

  const grid = cssVar('--line');
  const inkMute = cssVar('--ink-mute');
  const phosphor = cssVar('--phosphor');
  const mono = "'IBM Plex Mono', monospace";

  const sizeShades: Record<string, number> = { small: 0.35, medium: 0.6, large: 1 };

  chart = new Chart(canvas.value, {
    type: 'bar',
    data: {
      labels: orderedSerializers(),
      datasets: props.sizes.map((size) => ({
        label: size,
        data: orderedSerializers().map((s) => ipsAt(s, size)),
        backgroundColor: props.sizes.map((s) => hexAlpha(phosphor, sizeShades[s] ?? 0.6)),
      })),
    },
    options: {
      indexAxis: 'y' as const,
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 400 },
      scales: {
        x: {
          type: 'logarithmic',
          grid: { color: grid },
          border: { color: grid },
          ticks: { color: inkMute, font: { family: mono, size: 10 } },
        },
        y: {
          grid: { display: false },
          border: { color: grid },
          ticks: { color: inkMute, font: { family: mono, size: 11 } },
        },
      },
      plugins: {
        legend: {
          labels: { color: inkMute, font: { family: mono, size: 10 }, boxWidth: 10, boxHeight: 10 },
        },
        tooltip: {
          callbacks: {
            label: (ctx) => {
              const ips = ctx.parsed.x as number;
              return `${ctx.dataset.label}: ${ips < 10 ? ips.toFixed(2) : ips.toFixed(0)} ips (${(1000 / ips).toFixed(1)} ms/op)`;
            },
          },
        },
      },
    },
  });
}

function hexAlpha(hex: string, alpha: number): string {
  const clean = hex.replace('#', '');
  const r = parseInt(clean.slice(0, 2), 16);
  const g = parseInt(clean.slice(2, 4), 16);
  const b = parseInt(clean.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

let themeObserver: MutationObserver | null = null;

onMounted(() => {
  build();
  themeObserver = new MutationObserver(build);
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
});

onBeforeUnmount(() => {
  themeObserver?.disconnect();
  chart?.destroy();
});

watch(() => [props.op, props.format, props.envKey, props.serializers.join(','), props.sizes.join(',')], build);
</script>

<template>
  <figure class="border border-line bg-panel p-4">
    <figcaption class="mb-3">
      <p class="font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute">Consistency across input sizes — log scale</p>
      <p class="font-mono text-[11px] text-inkmute mt-1">A library that wins at every size is a safe default; one that wins only at {{ sizes[sizes.length - 1] }} fits that workload.</p>
    </figcaption>
    <div class="h-72">
      <canvas ref="canvas" role="img" aria-label="Bar chart comparing serializers across input sizes"></canvas>
    </div>
  </figure>
</template>
