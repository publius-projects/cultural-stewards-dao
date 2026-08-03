import Layout from "@/components/Layout";
import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import digitalDao from "@/assets/digital-dao.png";
import digitalInfrastructure from "@/assets/digital-infrastructure.png";

const DigitalDao = () => {
  return (
    <Layout>
      <div className="space-y-8 max-w-2xl mx-auto" style={{ fontFamily: "'Times New Roman', Times, serif" }}>
        <p className="text-xs tracking-widest opacity-50 uppercase">Cultural Stewards Experiment — THE LAYERS</p>
        <h1 className="text-4xl font-bold tracking-tight md:text-4xl">Digital Layer</h1>
        <div className="w-full overflow-hidden">
          <img src={digitalDao} alt="DigitalDAO" className="w-full h-auto" />
        </div>
        <p className="text-base leading-relaxed opacity-70">
          The Digital Layer is the technical backbone of the entire ecosystem. It maintains the codebase that powers every interface participants interact with — from the governance forum to the physical event experiences — and is the only layer of its kind, existing as a single instance.
        </p>

        <hr className="border-foreground/15" />

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">At a glance</h2>
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "Treasury", value: "Allowance-based" },
              { label: "Instances", value: "One only" },
              { label: "Membership", value: "Proof of code" },
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
              { title: "Owns and maintains the codebase", body: "The Digital Layer owns the GitHub repository containing the code for every online interface in the ecosystem — including the UI experiences used at physical events. All of this is managed in a single repository, making it the shared technical foundation everything else depends on." },
              { title: "Pays for digital work", body: "The Digital Layer has two routes for compensating contributors: retroactive payment (submitting a receipt for work already done) and project funding (proposing a budget for work not yet started). Both routes draw from an allowance granted by the Primary Layer's central treasury — the Digital Layer holds no funds of its own." },
              { title: "A meritocratic community of builders", body: "Membership is earned through verified code contributions. Anyone can make commits to the GitHub repository and, if accepted, claim a Member role on-chain. Leadership — the Repository Stewards — are elected by Members from among themselves on a rotating basis." },
              { title: "Subject to Primary Layer oversight", body: "Unlike the Idea Layer, the Digital Layer cannot change its own governance rules unilaterally. The Primary Layer retains the right to veto any mandate adoption proposals, ensuring the technical infrastructure stays aligned with the broader ecosystem's constitutional framework." },
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
              src={digitalInfrastructure}
              alt="Floating panels of code and interface fragments receding into a luminous corridor — a visual representation of the ecosystem's digital infrastructure."
              className="w-full h-auto"
            />
          </div>
          <figcaption className="text-xs opacity-50 leading-relaxed">
            The digital infrastructure of the ecosystem — the shared codebase, interfaces, and online environments maintained by the Digital Layer.
          </figcaption>
        </figure>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Roles inside the Digital Layer</h2>
          <div className="border border-foreground/15">
            {[
              { name: "Members", text: "Participants who have made verified commits to the repository and claimed their on-chain role. They can vote on funding proposals, initiate governance changes, veto membership revocations, nominate themselves in elections, and vote on who becomes a Repository Steward." },
              { name: "Repository Stewards", text: "Elected from among Members to lead the Digital Layer's operations. They approve receipts and project funding, request allowances from the Primary Layer, execute governance changes, and hold admin rights on the GitHub repository itself. If a Repository Steward loses their role on-chain, their GitHub admin rights are automatically revoked." },
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
          <h2 className="text-xs tracking-widest opacity-50 uppercase">How to join</h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {[
              { step: "Step 1", title: "Contribute code", body: "Make commits to the ecosystem's GitHub repository. Anyone can contribute — no membership is required to start." },
              { step: "Step 2", title: "Apply on-chain", body: "Submit your GitHub branch and commit paths to the governance system as proof of your contribution." },
              { step: "Step 3", title: "Claim your role", body: "Once your application is verified, claim your Member role on-chain and begin participating in governance." },
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
          <h2 className="text-xs tracking-widest opacity-50 uppercase">How payments work</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {[
              { tag: "Retroactive", title: "Receipt payments", body: "For work already completed. Anyone — including non-members — can submit a receipt. A Repository Steward reviews and approves it, then payment is released from the treasury allowance." },
              { tag: "Prospective", title: "Project funding", body: "For work not yet started. Members propose a project and budget, which is put to a vote. If approved by Repository Stewards, funding is released in advance of the work being done." },
            ].map((p) => (
              <div key={p.tag} className="border border-foreground/15 p-4">
                <p className="text-xs opacity-60 mb-1">{p.tag}</p>
                <h3 className="text-sm mb-1">{p.title}</h3>
                <p className="text-sm leading-relaxed opacity-70">{p.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Checks and balances</h2>
          <div className="space-y-2">
            <div className="border border-foreground/15 p-4">
              <h3 className="text-sm mb-1">Members can veto allowance requests</h3>
              <p className="text-sm leading-relaxed opacity-70">When Repository Stewards want to request additional funds from the Primary Layer, Members have the power to block the request before it is submitted. This ensures the community retains a check on how resources are pursued.</p>
            </div>
            <div className="border border-foreground/15 p-4">
              <h3 className="text-sm mb-1">A Vote of No Confidence can reset leadership</h3>
              <p className="text-sm leading-relaxed opacity-70">If Members lose confidence in the elected Repository Stewards, they can trigger a Vote of No Confidence — requiring a high threshold and quorum — to immediately revoke all Repository Steward roles and launch a fresh election.</p>
            </div>
          </div>
        </section>

        <div className="border-l-2 border-foreground/40 pl-4 py-2">
          <p className="text-sm leading-relaxed opacity-80">
            <span className="font-bold">In short:</span> The Digital Layer is a singleton — there is only ever one — and it underpins everything in the ecosystem. Joining is straightforward if you can write code: contribute to the repository, prove it on-chain, and you are in. From there, you help shape and sustain the infrastructure that the whole community relies on.
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

export default DigitalDao;
