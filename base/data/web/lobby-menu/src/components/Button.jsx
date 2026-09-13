import { h } from 'preact';

export function Button({ children, className = '', ...props }) {
  return <button type="button" className={'ui-button ' + className} {...props}>{children}</button>;
}

export function SettingRow({ label, value, ...props }) {
  return <Button className="setting-row" {...props}>
    <span className="setting-label">{label}</span>{value && <span className="setting-value">{value}</span>}
  </Button>;
}
