// Random two-word name generator (adjective-noun)

const ADJECTIVES = [
  'bold', 'calm', 'cool', 'dark', 'deep', 'fair', 'fast', 'free', 'gold',
  'good', 'gray', 'keen', 'kind', 'late', 'lean', 'live', 'loud', 'mint',
  'neat', 'nice', 'pale', 'pure', 'rare', 'rich', 'safe', 'slim', 'soft',
  'sure', 'tall', 'tidy', 'tiny', 'true', 'warm', 'wide', 'wild', 'wise',
  'blue', 'red', 'green', 'swift', 'bright', 'quick', 'sharp', 'fresh',
]

const NOUNS = [
  'arch', 'band', 'beam', 'bell', 'bird', 'bloom', 'bolt', 'bond', 'boot',
  'boss', 'bowl', 'cape', 'cave', 'chip', 'clay', 'cliff', 'cloud', 'coin',
  'core', 'crab', 'crow', 'dawn', 'deer', 'dome', 'dove', 'drop', 'drum',
  'dusk', 'dust', 'elm', 'fern', 'fish', 'flame', 'flash', 'flint', 'foam',
  'fork', 'fort', 'fox', 'frost', 'gate', 'gaze', 'gem', 'glow', 'grove',
  'hawk', 'haze', 'helm', 'hill', 'hive', 'hold', 'horn', 'jade', 'jazz',
  'kelp', 'kite', 'knot', 'lake', 'lamp', 'lane', 'lark', 'leaf', 'ledge',
  'lion', 'lynx', 'mist', 'moon', 'moss', 'nest', 'node', 'oak', 'owl',
  'palm', 'path', 'peak', 'pine', 'pond', 'pool', 'rain', 'reef', 'ridge',
  'ring', 'rise', 'river', 'road', 'rock', 'root', 'rose', 'rust', 'sage',
  'sand', 'seal', 'seed', 'shell', 'shore', 'silk', 'snow', 'spark', 'star',
  'stem', 'stone', 'storm', 'sun', 'swan', 'thorn', 'tide', 'trail', 'tree',
  'vale', 'vine', 'wave', 'well', 'wind', 'wing', 'wolf', 'wood', 'yarn',
]

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)]
}

export function generateSessionName(): string {
  return `${pick(ADJECTIVES)}-${pick(NOUNS)}`
}
