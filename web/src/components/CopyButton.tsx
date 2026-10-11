import { useEffect, useRef, useState } from 'react';
import { CheckIcon, CopyIcon } from './Icons';

interface CopyButtonProps {
  value: string;
  /** What is being copied, used in the accessible name: "Copy token address". */
  label: string;
}

export function CopyButton({ value, label }: CopyButtonProps) {
  const [copied, setCopied] = useState(false);
  const [failed, setFailed] = useState(false);
  const timer = useRef<number | null>(null);

  useEffect(() => () => {
    if (timer.current) window.clearTimeout(timer.current);
  }, []);

  async function copy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setFailed(false);
    } catch {
      setFailed(true);
      setCopied(false);
    }
    if (timer.current) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      setCopied(false);
      setFailed(false);
    }, 2000);
  }

  const text = copied ? 'Copied' : failed ? 'Select and copy' : 'Copy';

  return (
    <button type="button" className="button button--ghost button--small copy-button" onClick={copy} aria-label={`${text}: ${label}`}>
      {copied ? <CheckIcon /> : <CopyIcon />}
      <span>{text}</span>
    </button>
  );
}
