export function Brand() {
  return (
    <a className="brand" href="#top" aria-label="Wheelio home">
      <svg viewBox="0 0 36 36" fill="none" aria-hidden="true">
        <rect width="36" height="36" rx="12" fill="currentColor" />
        <path
          d="m8 12 4 13 6-9 6 9 4-13"
          stroke="white"
          strokeWidth="2.7"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      <span>Wheelio<span className="brand-dot">.</span></span>
    </a>
  );
}
