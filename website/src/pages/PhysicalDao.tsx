import Layout from "@/components/Layout";
import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import physicalDao from "@/assets/physical-dao.png";
import culturalArtefacts from "@/assets/cultural-artefacts.png";

const PhysicalDao = () => {
  return (
    <Layout>
      <div className="space-y-8 max-w-2xl mx-auto" style={{ fontFamily: "'Times New Roman', Times, serif" }}>
        <p className="text-xs tracking-widest opacity-50 uppercase">Cultural Stewards Experiment — THE LAYERS</p>
         <h1 className="text-4xl font-bold tracking-tight md:text-4xl">What is the Convergence Layer?</h1>
        <div className="w-full overflow-hidden">
          <img src={physicalDao} alt="PhysicalDAO" className="w-full h-auto" />
        </div>
        <p className="text-base leading-relaxed opacity-70">
          The Convergence Layer is where the ecosystem gathers in live settings. It organises and governs all physical, online or hybrid events — exhibitions, workshops, symposiums, and more — managing everything from venue access and expenses to the sale of cultural artefacts and the rewarding of participants who show up.
        </p>

        <hr className="border-foreground/15" />

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">At a glance</h2>
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "Treasury", value: "Allowance-based" },
              { label: "Instances", value: "Multiple" },
              { label: "Membership", value: "Show up, earn a token" },
              { label: "Primary Layer veto", value: "Yes" },
            ].map((m) => (
              <div key={m.label} className="border border-foreground/15 p-4">
                <p className="text-xs opacity-60 mb-1">{m.label}</p>
                <p className="text-lg">{m.value}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">What it's for</h2>
          <div className="space-y-2">
            {[
              { title: "Manages real-world events and spaces", body: "Each Convergence Layer is responsible for a specific event or space — covering venue rental, physical access, equipment, logistics, and any other real-world assets needed to make it happen. Multiple Convergence Layers can exist simultaneously, each one operating independently once created." },
              { title: "Spawned by Idea Layers, not created directly", body: "A Convergence Layer can only come into existence after an Idea Layer proposes it and the Primary Layer approves. This means every physical event in the ecosystem has roots in a community-driven idea, not a top-down directive." },
              { title: "Sells cultural artefacts on behalf of creators", body: "Creators can designate a Convergence Layer as an operator for their NFTs, turning events into exchange platforms for cultural artefact sales. Creators retain independent selling rights — their work is not locked into the system — but the Convergence Layer facilitates sales at the event and distributes income according to a preset split." },
              { title: "Bridges on-chain governance and off-chain law", body: "Because Convergence Layers interact with real-world jurisdictions — contracts, venues, legal entities — each one is assigned a Legal Interfacer by the Primary Layer. This person acts as the bridge between the on-chain governance structure and the legal frameworks of the physical world, and holds the power to pause or unpause the layer's operations." },
            ].map((c) => (
              <div key={c.title} className="border border-foreground/15 p-4">
                <h3 className="text-sm mb-1">{c.title}</h3>
                <p className="text-sm leading-relaxed opacity-70">{c.body}</p>
              </div>
            ))}
          </div>
        </section>

        <figure className="space-y-2">
          <div className="w-full overflow-hidden border border-foreground/15">
            <img
              src={culturalArtefacts}
              alt="Digital cultural artefacts displayed in an illuminated vitrine — vessels, jars and forms representing NFTs handled by the Convergence Layer."
              className="w-full h-auto"
            />
          </div>
          <figcaption className="text-xs opacity-50 leading-relaxed">
            Digital cultural artefacts — NFTs designated to a Convergence Layer for sale at events, which could also be tied to physical objects.
          </figcaption>
        </figure>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Roles inside the Convergence Layer</h2>
          <div className="border border-foreground/15">
            {[
              { name: "Attendees", text: "Participants who have attended an event and hold a recently issued token from the Convergence Layer. Attendees gain formal governance rights — including the power to vote on Merit Token proposals and to initiate governance changes. Attendance Badges are valid for 15 days after issuance for the purpose of claiming membership." },
              { name: "Session Stewards", text: "Up to three per Convergence Layer, selected through a Peer Selection process. Session Stewards handle the day-to-day running of events: paying expenses, minting and distributing Attendance Badges, selling artefacts, and proposing Merit Token awards. They are nominated by the public and elected by Attendees." },
              { name: "Legal Interfacers", text: "Assigned by the Primary Layer to handle off-chain legal responsibilities. They vet and manage Session Steward nominations, and hold a critical power: they can adopt or revoke the set of executive mandates — effectively pausing or resuming the Convergence Layer's operations. Must be over 18 and based in an eligible jurisdiction (currently GBR)." },
            ].map((r, i, arr) => (
              <div
                key={r.name}
                className={`p-4 ${i < arr.length - 1 ? "border-b border-foreground/15" : ""}`}
              >
                <p className="text-sm mb-1">{r.name}</p>
                <p className="text-sm leading-relaxed opacity-70">{r.text}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">How to get involved</h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {[
              { step: "As a visitor", title: "Just show up", body: "Attend a physical event. No wallet or prior involvement needed to experience the space." },
              { step: "As a participant", title: "Collect your badge", body: "Receive an Attendance Badge (POAP) from a Session Steward at the event. This token activates your governance rights within the Convergence Layer, and can later be used to apply for Primary Layer membership." },
              { step: "As a contributor", title: "Earn Merit Tokens", body: "Go beyond attending — contribute to the event. Session Stewards can nominate you for a Merit Token, which Attendees vote to award. Merit Tokens can be redeemed for a financial reward by burning them on-chain." },
            ].map((s) => (
              <div key={s.step} className="border border-foreground/15 p-4">
                <p className="text-xs opacity-60 mb-1">{s.step}</p>
                <h3 className="text-sm mb-1">{s.title}</h3>
                <p className="text-sm leading-relaxed opacity-70">{s.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Tokens you can earn</h2>
          <div className="border border-foreground/15">
            {[
              { pill: "Attendance Badge", text: "A POAP issued by Session Stewards at the event. Valid for 15 days for claiming membership in the Convergence Layer. Can also be used to apply for Primary Layer membership — making it a passport into the broader governance ecosystem." },
              { pill: "Merit Token", text: "A soulbound token awarded for active contributions at an event. Unlike the Attendance Badge, Merit Tokens have real financial value — burning one on-chain triggers an automatic release of funds to your wallet from the treasury." },
            ].map((t, i, arr) => (
              <div
                key={t.pill}
                className={`p-4 flex items-start gap-3 ${i < arr.length - 1 ? "border-b border-foreground/15" : ""}`}
              >
                <span className="text-xs px-2 py-1 border border-foreground whitespace-nowrap">{t.pill}</span>
                <p className="text-sm leading-relaxed opacity-70">{t.text}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Checks and balances</h2>
          <div className="space-y-2">
            <div className="border border-foreground/15 p-4">
              <h3 className="text-sm mb-1">Attendees initiate, Primary Layer can veto, Session Stewards execute</h3>
              <p className="text-sm leading-relaxed opacity-70">Governance changes in a Convergence Layer follow a three-stage flow. Attendees propose them (requiring high threshold and quorum), the Primary Layer has a window to veto, and Session Stewards execute if no veto is cast. This layered structure keeps community voice central while maintaining constitutional oversight.</p>
            </div>
            <div className="border border-foreground/15 p-4">
              <h3 className="text-sm mb-1">Legal Interfacers act as a pause mechanism</h3>
              <p className="text-sm leading-relaxed opacity-70">If real-world legal or compliance concerns arise, Legal Interfacers can revoke the executive mandates — effectively pausing all operational activity in the Convergence Layer until conditions are resolved and mandates are re-adopted.</p>
            </div>
          </div>
        </section>

        <div className="border-l-2 border-foreground/40 pl-4 py-2">
          <p className="text-sm leading-relaxed opacity-80">
            <span className="font-bold">In short:</span> The Convergence Layer is the most tangible part of the ecosystem — the place where on-chain governance produces real-world results. Events, spaces, artefacts, and in-person community are all managed here. You can participate simply by showing up, and the more you contribute, the more the ecosystem rewards you for it.
          </p>
        </div>

        <div className="flex justify-center pt-4">
          <Link to="/" className="inline-flex items-center gap-2 text-sm tracking-widest uppercase opacity-60 hover:opacity-100 transition-opacity">
            <ArrowLeft size={16} /> EXPLORE OTHER LAYERS
          </Link>
        </div>
      </div>
    </Layout>
  );
};

export default PhysicalDao;
