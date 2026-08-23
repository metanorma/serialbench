<script setup lang="ts">
import type { MemoryRow } from '../lib/dashboard';
import { formatMemory } from '../lib/dashboard';
import { channelColor } from '../lib/channels';

const props = defineProps<{ rows: MemoryRow[]; size: string }>();

const maxAllocated = () => Math.max(...props.rows.map((r) => r.allocated), 0.0001);
</script>

<template>
  <figure class="border border-line bg-panel p-4">
    <figcaption class="mb-4">
      <p class="font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute">Memory — {{ size }} input, lower is better</p>
      <p class="font-mono text-[11px] text-inkmute mt-1">
        Solid: allocated during operation · outline: retained afterwards
      </p>
    </figcaption>

    <ul class="space-y-2.5" role="list">
      <li v-for="row in rows" :key="row.serializer" class="grid grid-cols-[minmax(6rem,8rem)_1fr_minmax(6rem,7rem)] gap-x-3 items-center">
        <span class="flex items-center gap-2 font-mono text-[13px] truncate min-w-0" :style="{ color: channelColor(row.serializer) }">
          <span class="h-2 w-2 shrink-0 rounded-full" :style="{ background: channelColor(row.serializer) }" />
          {{ row.serializer }}
        </span>

        <span class="relative h-5 graticule rounded-sm">
          <span
            class="absolute inset-y-[2px] left-0 rounded-[2px]"
            :style="{ width: `${(row.allocated / maxAllocated()) * 100}%`, background: channelColor(row.serializer), opacity: 0.4 }"
          />
          <span
            class="absolute inset-y-[2px] left-0 rounded-[2px] border"
            :style="{ width: `${(row.retained / maxAllocated()) * 100}%`, borderColor: channelColor(row.serializer) }"
          />
        </span>

        <span class="text-right font-mono text-[12px] tabular text-inkdim">
          {{ formatMemory(row.allocated) }}
        </span>
      </li>
    </ul>
  </figure>
</template>
