<script setup lang="ts">
import { computed, ref } from 'vue';
import type { LeaderRow } from '../lib/dashboard';

const props = defineProps<{
  rows: LeaderRow[];
  reference: string | null;
  format: string;
  op: string;
  size: string;
  envLabel: string;
  generatedAt: string;
}>();

const copied = ref(false);

const effectiveReference = computed(() => props.reference ?? props.rows[0]?.serializer ?? null);
const second = computed(() => props.rows.find((r) => r.serializer !== effectiveReference.value));
const ratio = computed(() => second.value?.ratioToRef ?? null);

const opVerb = computed(() => ({ parsing: 'parses', generation: 'generates', streaming: 'streams' })[props.op] ?? props.op);

const citation = computed(() => {
  const date = props.generatedAt.slice(0, 10);
  if (!effectiveReference.value || !second.value || !ratio.value) {
    return 'Pin a reference library to generate a citable claim.';
  }
  return `${effectiveReference.value} ${opVerb.value} ${props.size} ${props.format.toUpperCase()} ${ratio.value.toFixed(1)}× faster than ${second.value.serializer} on ${props.envLabel} — serialbench, ${date}`;
});

async function copy() {
  await navigator.clipboard.writeText(citation.value);
  copied.value = true;
  setTimeout(() => (copied.value = false), 1600);
}
</script>

<template>
  <figure class="border border-line bg-panel px-4 py-3 flex flex-wrap items-center gap-4">
    <span class="font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute shrink-0">Cite this</span>
    <blockquote class="flex-1 min-w-64 font-mono text-[12px] leading-relaxed text-inkdim">“{{ citation }}”</blockquote>
    <button
      type="button"
      class="shrink-0 font-mono text-[10px] uppercase tracking-wider border border-line px-2.5 py-1 text-inkdim hover:border-phosphor hover:text-phosphor transition-colors"
      @click="copy"
    >
      {{ copied ? 'Copied' : 'Copy' }}
    </button>
  </figure>
</template>
