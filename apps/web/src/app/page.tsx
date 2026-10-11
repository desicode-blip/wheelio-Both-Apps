import { Brand } from "@/components/brand";
import { WashIllustration } from "@/components/wash-illustration";

const steps = [
  {
    number: "01",
    title: "Pick your wash",
    description: "Choose your car or bike, tell us where it’s parked, and pick a time that works for you.",
  },
  {
    number: "02",
    title: "We come to your parking spot",
    description: "Your captain takes care of the exterior wash while you get on with your day.",
  },
  {
    number: "03",
    title: "See the shine. Approve the wash.",
    description: "Review the before-and-after photos. Your payment is released after you approve.",
  },
];

export default function Home() {
  return (
    <div id="top">
      <a className="skip-link" href="#main">Skip to content</a>
      <header className="site-header container">
        <Brand />
        <nav aria-label="Main navigation">
          <a href="#how-it-works">How it works</a>
          <a href="#the-wheelio-way">Why Wheelio</a>
          <a className="nav-launch" href="#launch">Coming soon <span aria-hidden="true">↗</span></a>
        </nav>
      </header>

      <main id="main">
        <section className="hero container" aria-labelledby="hero-title">
          <div className="hero-copy">
            <p className="eyebrow"><span className="location-pin" aria-hidden="true">⌖</span> Made for Hyderabad’s gated societies</p>
            <h1 id="hero-title">A clean ride.<br /><span>Without the detour.</span></h1>
            <p className="hero-description">Car and bike washes, right where you park. A little care for your wheels. A little more time for you.</p>
            <a className="button" href="#how-it-works">Meet your next wash <span aria-hidden="true">→</span></a>
            <p className="hero-note">Pay per wash · Photo verified · At your doorstep</p>
          </div>
          <div className="hero-art">
            <div className="art-caption"><span aria-hidden="true">✦</span> Clean wheels, zero hassle</div>
            <WashIllustration />
            <div className="art-footer"><span className="photo-icon" aria-hidden="true">▣</span><div><strong>A shine you can see.</strong><span>Before-and-after photos with every wash.</span></div></div>
          </div>
        </section>

        <section id="how-it-works" className="how-section container" aria-labelledby="how-title">
          <div className="section-heading"><p className="eyebrow">LESS RUNNING AROUND. MORE GETTING ON WITH LIFE.</p><h2 id="how-title">Your wash, in three simple steps.</h2></div>
          <ol className="steps">
            {steps.map((step) => (
              <li key={step.number}><span className="step-number" aria-hidden="true">{step.number}</span><h3>{step.title}</h3><p>{step.description}</p></li>
            ))}
          </ol>
        </section>

        <section id="the-wheelio-way" className="care-section container" aria-labelledby="care-title">
          <div><p className="eyebrow">THE WHEELIO WAY</p><h2 id="care-title">Good care.<br />Clear proof.</h2><p>A wash should be one less thing to think about. Wheelio brings exterior care to your society, with the details kept simple.</p></div>
          <ul className="care-list">
            <li><span aria-hidden="true">01</span><div><h3>One wash at a time</h3><p>Pay for the wash you need. No subscription to keep track of.</p></div></li>
            <li><span aria-hidden="true">02</span><div><h3>Photos, before and after</h3><p>See the work for yourself, from wherever you are.</p></div></li>
            <li><span aria-hidden="true">03</span><div><h3>You give the go-ahead</h3><p>Your money is held until you approve the completed wash.</p></div></li>
          </ul>
        </section>

        <section id="launch" className="launch-section container" aria-labelledby="launch-title">
          <p className="eyebrow">COMING SOON TO HYDERABAD</p>
          <h2 id="launch-title">The first shine is on its way.</h2>
          <p>We’re getting Wheelio ready. App downloads and booking details will be available here when we launch.</p>
          <span className="launch-label">Stay tuned <span aria-hidden="true">↗</span></span>
        </section>
      </main>

      <footer className="site-footer container"><Brand /><p>Clean wheels, zero hassle.</p><a href="#top">Back to top <span aria-hidden="true">↑</span></a></footer>
    </div>
  );
}
