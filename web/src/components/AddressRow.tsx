import { explorerAddress } from '../config';
import { CopyButton } from './CopyButton';
import { ExternalIcon } from './Icons';

interface AddressRowProps {
  label: string;
  address: string;
  note?: string;
}

export function AddressRow({ label, address, note }: AddressRowProps) {
  return (
    <div className="address-row">
      <div className="address-row__meta">
        <span className="address-row__label">{label}</span>
        {note ? <span className="address-row__note">{note}</span> : null}
      </div>
      <code className="address-row__value">{address}</code>
      <div className="address-row__actions">
        <CopyButton value={address} label={`${label} address`} />
        <a
          className="button button--ghost button--small"
          href={explorerAddress(address)}
          target="_blank"
          rel="noopener noreferrer"
        >
          <ExternalIcon />
          <span>
            Etherscan<span className="visually-hidden"> page for {label}</span>
          </span>
        </a>
      </div>
    </div>
  );
}
