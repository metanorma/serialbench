<script setup lang="ts">
import { computed, ref } from 'vue';
import type { LeaderRow } from '../lib/dashboard';
import { formatIps } from '../lib/dashboard';
import { channelColor } from '../lib/channels';

const props = defineProps<{
  rows: LeaderRow[];
  reference: string | null;
  caption: string;
}>();

const emit = defineEmits<{ pin: [serializer: string] }>();

const logScale = ref(false);

const effectiveReference = computed(() => props.reference ?? props.rows[0]?.serializer ?? null);

const maxIps = computed(() => props.rows[0]?.ips ?? 0);
const minIps = computed(() => props.rows[props.rows.length - 1]?.ips ?? 0);

const logSpan = computed(() => ({
  lo: Math.log10(Math.max(minIps.value * 0.8, 0.01)),
  hi: Math.log10(maxIps.value * 1.05),
}));

function widthFor(row: LeaderRow): number {
  if (maxIps.value <= 0) return 0;
  if (!logScale.value) return (row.ips / maxIps.value) * 100;
  const { lo, hi } = logSpan.value;
  return ((Math.log10(row.ips) - lo) / (hi - lo)) * 100;
}

const ticks = computed(() => {
  const positions = [0, 0.25, 0.5, 0.75, 1];
  return positions.map((p) => {
    const value = logScale.value
      ? 10 ** (logSpan.value.lo + p * (logSpan.value.hi - logSpan.value.lo))
      : p * maxIps.value;
    return { pct: p * 100, label: formatIps(value) };
  });
});
</script>

<template>
  <div>
    <div class="flex items-baseline justify-between gap-4 mb-3 flex-wrap">
      <div>
        <p class="font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute">Field ranking — iterations per second, higher is better</p>
        <p class="font-mono text-[11px] text-inkmute mt-1">{{ caption }}</p>
      </div>
      <div class="flex border border-line divide-x divide-line" role="group" aria-label="Scale">
        <button
          type="button"
          class="px-2.5 py-1 font-mono text-[10px] uppercase tracking-wider transition-colors"
          :class="!logScale ? 'bg-panel2 text-ink' : 'text-inkmute hover:text-inkdim'"
          :aria-pressed="!logScale"
          @click="logScale = false"
        >
          Linear
        </button>
        <button
          type="button"
          class="px-2.5 py-1 font-mono text-[10px] uppercase tracking-wider transition-colors"
          :class="logScale ? 'bg-panel2 text-ink' : 'text-inkmute hover:text-inkdim'"
          :aria-pressed="logScale"
          @click="logScale = true"
        >
          Log
        </button>
      </div>
    </div>

    <!-- axis -->
    <div class="grid grid-cols-[minmax(7rem,10rem)_1fr_minmax(8rem,9rem)] gap-x-3 items-center mb-1">
      <span />
      <div class="relative h-4">
        <span
          v-for="tick in ticks"
          :key="tick.pct"
          class="absolute top-0 font-mono text-[10px] text-inkmute tabular -translate-x-1/2"
          :style="{ left: `${tick.pct}%` }"
        >{{ tick.label }}</span>
      </div>
      <span class="font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute text-right">vs ref</span>
    </div>

    <ul class="space-y-1.5" role="list">
      <li v-for="(row, i) in rows" :key="row.serializer">
        <button
          type="button"
          class="grid grid-cols-[minmax(7rem,10rem)_1fr_minmax(8rem,9rem)] gap-x-3 items-center w-full text-left group rounded-sm focus-visible:outline-offset-4 py-0.5"
          :aria-pressed="row.serializer === reference"
          :title="row.serializer === reference ? 'Unpin reference' : 'Pin as reference'"
          @click="emit('pin', row.serializer)"
        >
          <span class="flex items-center gap-2 font-mono text-[13px] truncate min-w-0" :style="{ color: channelColor(row.serializer) }">
            <span class="h-2 w-2 shrink-0 rounded-full" :style="{ background: channelColor(row.serializer) }" />
            <span class="truncate group-hover:translate-x-0.5 transition-transform">{{ row.serializer }}</span>
          </span>

          <span class="relative h-7 graticule rounded-sm overflow-hidden">
            <span
              class="absolute inset-y-[3px] left-0 rounded-[2px] trace-in"
              :style="{
                width: `${Math.max(widthFor(row), 0.75)}%`,
                background: channelColor(row.serializer),
                opacity: row.serializer === effectiveReference || !reference ? 0.95 : 0.6,
                animationDelay: `${i * 60}ms`,
              }"
            />
          </span>

          <span class="flex items-baseline justify-end gap-2 whitespace-nowrap">
            <span class="tabular font-mono text-[13px] text-ink">{{ formatIps(row.ips) }}<span class="text-inkmute text-[11px]"> ips</span></span>
            <span
              v-if="row.serializer === effectiveReference"
              class="font-mono text-[10px] uppercase tracking-wider border border-phosphor text-phosphor px-1.5 py-px"
            >ref</span>
            <span v-else-if="row.ratioToRef" class="tabular font-mono text-[11px] text-inkmute">×{{ row.ratioToRef.toFixed(1) }}</span>
          </span>
        </button>
      </li>
    </ul>
  </div>
</template>
