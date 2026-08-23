// Channel assignment: every serializer keeps one color everywhere on the site
// (bars, chart strokes, availability dots), like scope channels on a bench
// instrument. Single source of truth — components import from here.
export const CHANNELS: Record<string, string> = {
  leptris: '#5fd4e8',
  nokogiri: '#f5a623',
  ox: '#e85d9e',
  oga: '#9b8cff',
  rexml: '#77879e',
  'libxml-ruby': '#d97b4a',
  oj: '#6ee7a0',
  json: '#b8c4d0',
  rapidjson: '#7be0d3',
  yajl: '#e8c56a',
  psych: '#c9a0dc',
  syck: '#8c7ae0',
  'toml-rb': '#e88b6a',
  tomlib: '#6ab0e8',
  tomlrb: '#d4e87b',
};

export function channelColor(serializer: string): string {
  return CHANNELS[serializer] ?? '#8fa3bf';
}
