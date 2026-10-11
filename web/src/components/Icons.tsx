// One icon set, 1.5px stroke beside regular text, recolored through currentColor.

interface IconProps {
  size?: number;
}

const common = {
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.5,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  'aria-hidden': true,
  focusable: false,
};

export function Logo({ size = 28 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true" focusable="false">
      <rect width="64" height="64" rx="14" fill="var(--color-accent-solid)" />
      <path
        d="M20 46 L32 16 L44 46"
        fill="none"
        stroke="#fff"
        strokeWidth="6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M25 36 H39" stroke="#fff" strokeWidth="6" strokeLinecap="round" />
    </svg>
  );
}

export function ExternalIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" {...common}>
      <path d="M6.5 3.5H3.5v9h9V9.5" />
      <path d="M9.5 2.5h4v4" />
      <path d="M13.5 2.5 7.5 8.5" />
    </svg>
  );
}

export function CopyIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" {...common}>
      <rect x="5.5" y="5.5" width="8" height="8" rx="1.5" />
      <path d="M10.5 5.5v-2a1 1 0 0 0-1-1h-6a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2" />
    </svg>
  );
}

export function CheckIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" {...common}>
      <path d="M3 8.5 6.5 12 13 4.5" />
    </svg>
  );
}

export function WalletIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" {...common}>
      <rect x="1.5" y="4" width="13" height="9.5" rx="2" />
      <path d="M1.5 6.5h13" />
      <path d="M10.5 10h1.5" />
    </svg>
  );
}

export function AlertIcon({ size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" {...common}>
      <circle cx="8" cy="8" r="6.25" />
      <path d="M8 5v3.5" />
      <path d="M8 11h.01" />
    </svg>
  );
}
