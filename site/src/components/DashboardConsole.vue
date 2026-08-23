<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import type { Payload } from '../lib/dashboard';
import {
  availableFormats,
  availableOperations,
  availableSizes,
  environmentLabel,
  environmentList,
  leaderboard,
  memoryRows,
  OPERATIONS,
  OPERATION_LABELS,
  serializersFor,
} from '../lib/dashboard';
import CalibratedLeaderboard from './CalibratedLeaderboard.vue';
import OpsChart from './OpsChart.vue';
import MemoryPanel from './MemoryPanel.vue';
import CitationBox from './CitationBox.vue';

const props = defineProps<{ payload: Payload }>();

const formats = computed(() => availableFormats(props.payload));
const format = ref(formats.value[0] ?? 'xml');

const operations = computed(() => availableOperations(props.payload, format.value));
const op = ref<string>('parsing');

const sizes = computed(() => availableSizes(props.payload, op.value, format.value));
const size = ref<string>('large');

const envs = computed(() => environmentList(props.payload));
const envKey = ref(envs.value[0]?.key ?? '');

const reference = ref<string | null>(null);

function syncToAvailable() {
  if (!operations.value.includes(op.value as (typeof OPERATIONS)[number])) {
    op.value = operations.value[0] ?? 'parsing';
  }
  if (!sizes.value.includes(size.value)) {
    size.value = sizes.value[sizes.value.length - 1] ?? 'small';
  }
  if (!envs.value.some((e) => e.key === envKey.value)) {
    envKey.value = envs.value[0]?.key ?? '';
  }
}

const state = computed(() => ({ format: format.value, op: op.value, size: size.value, env: envKey.value, ref: reference.value }));

function syncUrl() {
  const params = new URLSearchParams();
  params.set('f', format.value);
  params.set('op', op.value);
  if (sizes.value.length > 1) params.set('sz', size.value);
  params.set('env', envKey.value);
  if (reference.value) params.set('ref', reference.value);
  history.replaceState(null, '', `?${params.toString()}`);
}

watch(state, syncUrl);
watch([format], () => {
  reference.value = null;
  syncToAvailable();
});
watch([op], syncToAvailable);

onMounted(() => {
  const params = new URLSearchParams(location.search);
  const f = params.get('f');
  if (f && formats.value.includes(f)) format.value = f;
  syncToAvailable();
  const opParam = params.get('op');
  if (opParam && operations.value.includes(opParam as (typeof OPERATIONS)[number])) op.value = opParam;
  const sz = params.get('sz');
  if (sz && sizes.value.includes(sz)) size.value = sz;
  const env = params.get('env');
  if (env && envs.value.some((e) => e.key === env)) envKey.value = env;
  reference.value = params.get('ref');
});

const rows = computed(() =>
  leaderboard(props.payload, op.value, size.value, format.value, envKey.value, reference.value),
);

const mem = computed(() => memoryRows(props.payload, size.value, format.value, envKey.value));

const serializers = computed(() => serializersFor(props.payload, format.value));

const envLabel = computed(() => {
  const entry = envs.value.find((e) => e.key === envKey.value);
  return entry ? environmentLabel(entry.key, entry.env) : '';
});
</script>

<template>
  <section aria-label="Benchmark console">
    <!-- control rail -->
    <div class="flex flex-wrap items-end gap-x-8 gap-y-4 border-y border-line py-3 mb-8">
      <fieldset>
        <legend class="font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute mb-1.5">Format</legend>
        <div class="flex border border-line divide-x divide-line" role="group">
          <button
            v-for="f in formats"
            :key="f"
            type="button"
            class="px-3 py-1.5 font-mono text-xs uppercase tracking-wide transition-colors"
            :class="f === format ? 'bg-phosphor text-phosphorink' : 'text-inkdim hover:text-ink'"
            :aria-pressed="f === format"
            @click="format = f"
          >
            {{ f }}
          </button>
        </div>
      </fieldset>

      <fieldset>
        <legend class="font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute mb-1.5">Operation</legend>
        <div class="flex border border-line divide-x divide-line" role="group">
          <button
            v-for="o in operations"
            :key="o"
            type="button"
            class="px-3 py-1.5 font-mono text-xs uppercase tracking-wide transition-colors"
            :class="o === op ? 'bg-phosphor text-phosphorink' : 'text-inkdim hover:text-ink'"
            :aria-pressed="o === op"
            @click="op = o"
          >
            {{ OPERATION_LABELS[o as keyof typeof OPERATION_LABELS] ?? o }}
          </button>
        </div>
      </fieldset>

      <fieldset v-if="sizes.length > 1">
        <legend class="font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute mb-1.5">Input size</legend>
        <div class="flex border border-line divide-x divide-line" role="group">
          <button
            v-for="s in sizes"
            :key="s"
            type="button"
            class="px-3 py-1.5 font-mono text-xs uppercase tracking-wide transition-colors"
            :class="s === size ? 'bg-phosphor text-phosphorink' : 'text-inkdim hover:text-ink'"
            :aria-pressed="s === size"
            @click="size = s"
          >
            {{ s }}
          </button>
        </div>
      </fieldset>

      <label class="ml-auto">
        <span class="block font-mono text-[10px] uppercase tracking-[0.14em] text-inkmute mb-1.5">Environment</span>
        <select
          v-model="envKey"
          class="bg-panel border border-line px-3 py-1.5 font-mono text-xs text-inkdim hover:text-ink focus:text-ink transition-colors max-w-64"
        >
          <option v-for="e in envs" :key="e.key" :value="e.key">{{ environmentLabel(e.key, e.env) }}</option>
        </select>
      </label>
    </div>

    <CalibratedLeaderboard
      :rows="rows"
      :reference="reference"
      :caption="`${envLabel} · ${OPERATION_LABELS[op as keyof typeof OPERATION_LABELS] ?? op} · ${size} input`"
      @pin="(name: string) => (reference = reference === name ? null : name)"
    />

    <div class="grid lg:grid-cols-2 gap-6 mt-10">
      <OpsChart
        v-if="sizes.length > 1"
        :payload="payload"
        :op="op"
        :format="format"
        :sizes="sizes"
        :env-key="envKey"
        :serializers="serializers"
      />
      <MemoryPanel v-if="mem.length > 0" :rows="mem" :size="size" />
    </div>

    <CitationBox
      class="mt-6"
      :rows="rows"
      :reference="reference"
      :format="format"
      :op="op"
      :size="size"
      :env-label="envLabel"
      :generated-at="payload.metadata.generated_at"
    />
  </section>
</template>
