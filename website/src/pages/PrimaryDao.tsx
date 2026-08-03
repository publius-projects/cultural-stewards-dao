import Layout from "@/components/Layout";
import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import primaryDao from "@/assets/primary-dao.png";
import safeAllowance from "@/assets/safe-allowance.png";
import powersFactory from "@/assets/powers-factory.png";

const PrimaryDao = () => {
  return (
    <Layout>
      <div className="space-y-8 max-w-2xl mx-auto" style={{ fontFamily: "'Times New Roman', Times, serif" }}>
        <p className="text-xs tracking-widest opacity-50 uppercase">Cultural Stewards Experiment — THE LAYERS</p>
        <h1 className="text-4xl font-bold tracking-tight md:text-4xl">What is the Primary Layer?</h1>
        <p className="text-base leading-relaxed opacity-70">
          The Primary Layer is the central governance body of the Cultural Stewards ecosystem. Think of it as the constitutional core — it holds the shared treasury, sets the rules, and oversees the creation and activity of all other layers.
        </p>
        <div className="w-full overflow-hidden">
          <img src={primaryDao} alt="Primary Layer" className="w-full h-auto" />
        </div>

        <hr className="border-foreground/15" />

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">At a glance</h2>
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "Treasury", value: "Central Safe" },
              { label: "Layers overseen", value: "3 types" },
              { label: "Membership", value: "Earned, not assumed" },
              { label: "Governance model", value: "Federated" },
            ].map((m) => (
              <div key={m.label} className="border border-foreground/15 p-4">
                <p className="text-xs opacity-60 mb-1">{m.label}</p>
                <p className="text-lg">{m.value}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Core responsibilities</h2>
          <div className="space-y-2">
            {[
              {
                title: "Holds the treasury",
                body: "All funds in the ecosystem live in the Primary Layer's Safe smart wallet. Other layers do not hold their own funds — instead they operate on allowances granted by the Primary Layer. This keeps financial control centralised and secure.",
              },
              {
                title: "Creates and deactivates other layers",
                body: "New Idea Layers and Convergence Layers can only come into existence through the Primary Layer. It can also deactivate them and revoke their allowances if needed. It is the root of the entire ecosystem.",
              },
              {
                title: "Holds veto power",
                body: "The Primary Layer Primary Stewards can veto mandate changes proposed by any other layer. This acts as a constitutional check — other layers have operational freedom, but cannot make changes that conflict with the broader ecosystem's direction.",
              },
              {
                title: "Manages tokens and metadata",
                body: "The Primary Layer owns the ERC-1155 token contract that tracks participant activity. It also controls the URI — the metadata record that tells the platform which layers exist and how to display them.",
              },
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
              src={safeAllowance}
              alt="A worn leather wallet holding banknotes against a glitched digital backdrop — representing a Safe allowance module."
              className="w-full h-auto"
            />
          </div>
          <figcaption className="text-xs opacity-50 leading-relaxed">
            The Safe allowance module — the Primary Layer holds the treasury and grants bounded allowances that flow downstream to the Ideas and Convergence Layers.
          </figcaption>
        </figure>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Roles inside the Primary Layer</h2>
          <div className="border border-foreground/15">
            {[
              {
                name: "Primary Participants",
                text: "Participants with voting rights in the Primary Layer. Can initiate proposals, veto actions, and nominate candidates for Primary Steward elections. Membership is always earned indirectly — you must first contribute in one of the other layers.",
              },
              {
                name: "Primary Stewards",
                text: "Elected from among Primary Participants on a rotating basis. Responsible for executing high-level decisions — creating new layers, granting allowances, vetoing mandates, and managing the treasury. Roles are non-exclusive: a Primary Steward retains their Primary Participant rights.",
              },
              {
                name: "Recognised layers (as roles)",
                text: "Each recognised layer (Digital, Ideas, Physical) holds a formal role inside the Primary Layer. This allows them to participate in governance — for instance, proposing allowances or vetoing mandate reforms — as institutional actors rather than just individuals.",
              },
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
          <h2 className="text-xs tracking-widest opacity-50 uppercase">How do you become a Primary Participant?</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div className="border border-foreground/15 p-4">
              <p className="text-xs opacity-60 mb-1">Path A</p>
              <h3 className="text-sm mb-1">Via a Convergence Layer</h3>
              <p className="text-sm leading-relaxed opacity-70">Attend a physical event organised through a Convergence Layer and collect an Attendance Badge (POAP). You can then use this token to request Primary Layer membership.</p>
            </div>
            <div className="border border-foreground/15 p-4">
              <p className="text-xs opacity-60 mb-1">Path B</p>
              <h3 className="text-sm mb-1">Via an Idea Layer</h3>
              <p className="text-sm leading-relaxed opacity-70">Contribute actively in an Idea Layer and receive Election Tokens. An Idea Layer can then forward a membership request on your behalf, which you complete by proving token ownership.</p>
            </div>
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Checks and balances</h2>
          <div className="space-y-2">
            <div className="border border-foreground/15 p-4">
              <h3 className="text-sm mb-1">Adopting new mandates requires broad consensus</h3>
              <p className="text-sm leading-relaxed opacity-70">For the Primary Layer to change its own governance rules, the proposal must clear multiple veto gates: Primary Participants, Digital Layer, Idea Layer, and Convergence Layer each have the right to block adoption before Primary Stewards can finalise it. This prevents unilateral changes to the constitutional framework.</p>
            </div>
            <div className="border border-foreground/15 p-4">
              <h3 className="text-sm mb-1">A Vote of No Confidence can remove all Primary Stewards</h3>
              <p className="text-sm leading-relaxed opacity-70">If the Primary Participants collectively lose trust in the elected Primary Stewards, they can trigger a Vote of No Confidence (requiring a high threshold and quorum) to revoke all Primary Steward roles simultaneously and reset the leadership.</p>
            </div>
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">What is a Powers Factory?</h2>
          <figure className="space-y-2">
            <div className="w-full overflow-hidden border border-foreground/15">
              <img
                src={powersFactory}
                alt="A vast industrial refinery rendered as layered, glitched verticals reflected on water — a visual metaphor for a Powers Factory deploying new governance instances."
                className="w-full h-auto"
              />
            </div>
          </figure>
          <div className="border border-foreground/15 p-4">
            <p className="text-sm leading-relaxed opacity-70">
              A Powers Factory is a smart contract that deploys new governance instances on demand. The Primary Layer owns two: one for Idea Layers, one for Convergence Layers. Mandates are saved into the factory in advance, so when <code className="px-1 py-0.5 bg-foreground/10 rounded text-xs">createPowers</code> is called, a fully configured new layer is deployed instantly — consistent rules, every time, no manual setup.
            </p>
          </div>
        </section>

        <div className="border-l-2 border-foreground/40 pl-4 py-2">
          <p className="text-sm leading-relaxed opacity-80">
            <span className="font-bold">In short:</span> The Primary Layer is not where most day-to-day activity happens — that takes place in the other layers. But it is the constitutional anchor that everything else is built on. It holds the money, sets the limits, and ensures the whole ecosystem stays aligned with its shared mission.
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

export default PrimaryDao;
