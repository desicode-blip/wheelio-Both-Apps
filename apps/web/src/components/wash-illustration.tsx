export function WashIllustration() {
  return (
    <svg
      className="wash-illustration"
      viewBox="0 0 540 390"
      role="img"
      aria-labelledby="wash-title"
    >
      <title id="wash-title">A freshly washed blue car in a society parking space</title>
      <defs>
        <linearGradient id="car-paint" x1="0" y1="0" x2="0.8" y2="1">
          <stop stopColor="#537BFF" />
          <stop offset="1" stopColor="#1F4AD1" />
        </linearGradient>
      </defs>
      <circle cx="278" cy="185" r="145" fill="#DCE6FF" />
      <g fill="#CEDAF2">
        <rect x="55" y="88" width="74" height="150" rx="5" />
        <rect x="399" y="63" width="87" height="179" rx="5" />
      </g>
      <g fill="#EAF0FF">
        <path d="M70 109h13v17H70zm26 0h13v17H96zm-26 34h13v17H70zm26 0h13v17H96zm-26 34h13v17H70zm26 0h13v17H96z" />
        <path d="M414 85h15v18h-15zm30 0h15v18h-15zm-30 37h15v18h-15zm30 0h15v18h-15zm-30 37h15v18h-15zm30 0h15v18h-15z" />
      </g>
      <path d="M35 285h470" stroke="#B3C6EC" strokeWidth="2" />
      <ellipse cx="277" cy="283" rx="192" ry="19" fill="#BED0F3" />
      <path
        d="m123 207 52-70c7-9 17-14 28-14h105c15 0 26 5 37 17l50 55 54 12c12 3 20 13 20 25v30H89v-30c0-10 7-20 17-22z"
        fill="url(#car-paint)"
      />
      <path d="m177 150-36 49h101v-61h-40c-10 0-18 4-25 12zm81-12v61h116l-43-46c-10-11-17-15-29-15z" fill="#DDEBFF" />
      <path d="m171 193 37-49h20l-36 49zm98 0v-49h19v49z" fill="#F5F9FF" opacity=".7" />
      <path d="M102 223h34m291 0h27" stroke="#FFF4C5" strokeWidth="9" strokeLinecap="round" />
      <path d="M250 207v48m-72-32h25m72 0h25" stroke="#153FAB" strokeWidth="4" strokeLinecap="round" />
      <path d="M101 252h354" stroke="#153FAB" strokeWidth="8" strokeLinecap="round" />
      <g fill="#172231">
        <circle cx="166" cy="261" r="34" />
        <circle cx="393" cy="261" r="34" />
      </g>
      <g fill="#CFDAEB" stroke="#7B8DA9" strokeWidth="6">
        <circle cx="166" cy="261" r="18" />
        <circle cx="393" cy="261" r="18" />
      </g>
      <g fill="white" stroke="#3160FF" strokeWidth="2" strokeLinejoin="round">
        <path d="m383 98 7 19 19 7-19 7-7 19-7-19-19-7 19-7z" />
        <path d="m127 133 5 12 12 5-12 5-5 12-5-12-12-5 12-5z" />
        <path d="m446 173 4 10 10 4-10 4-4 10-4-10-10-4 10-4z" />
      </g>
      <g fill="none" stroke="#91ACE9" strokeWidth="2">
        <circle cx="332" cy="81" r="7" />
        <circle cx="91" cy="190" r="5" />
        <circle cx="468" cy="136" r="5" />
      </g>
    </svg>
  );
}
