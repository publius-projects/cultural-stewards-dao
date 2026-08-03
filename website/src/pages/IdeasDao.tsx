import Layout from "@/components/Layout";
import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import ideasDao from "@/assets/ideas-dao.png";
import ideasLayerBanner from "@/assets/ideas-layer-banner.png";
import ideasLayerListening from "@/assets/ideas-layer-listening.png";
import ideasLayerMaking from "@/assets/ideas-layer-making.png";
import ideasLayerSeeing from "@/assets/ideas-layer-seeing.png";
import ideasLayerTelling from "@/assets/ideas-layer-telling.png";
import ideasLayerRemembering from "@/assets/ideas-layer-remembering.png";
import ideasLayerTending from "@/assets/ideas-layer-tending.png";
import { ideasLayers } from "@/data/ideasLayers";

const signupIndex: Record<string, number> = {
  Telling: 0,
  Listening: 1,
  Imagining: 2,
  Seeing: 3,
  Remembering: 4,
  Tending: 5,
  Making: 6,
};

const IdeasDao = () => {
  return (
    <Layout>
      <div className="space-y-8 max-w-2xl mx-auto" style={{ fontFamily: "'Times New Roman', Times, serif" }}>
        <p className="text-xs tracking-widest opacity-50 uppercase">Cultural Stewards Experiment — THE LAYERS</p>
        <h1 className="text-4xl font-bold tracking-tight md:text-4xl">What is the Idea Layer?</h1>
        <p className="text-base leading-relaxed opacity-70">
          The Idea Layer is where new cultural initiatives are born. It is a free, experimental space for discussion, incubation, and community-building — and the only place in the ecosystem where proposals to create a Convergence Layer can originate.
        </p>
        <div className="w-full overflow-hidden">
          <img src={ideasDao} alt="IdeasDAO" className="w-full h-auto" />
        </div>

        {/* HIGH PRIORITY: Currently active Idea Layers — placed near the top so users can join immediately */}
        <section className="space-y-4">
          <div className="space-y-1 text-center">
            <p className="text-xs tracking-widest opacity-60 uppercase">Join now</p>
            <h2 className="text-2xl font-bold">Currently active Idea Layers</h2>
            <p className="text-sm opacity-70">Pick a layer below and complete the form to join the conversation.</p>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {ideasLayers.map(({ n, title, uriDescription }) => (
              <a
                key={n}
                href={`https://powers-utils.vercel.app/CS-signup?index=${signupIndex[title] ?? ""}`}
                target="_blank"
                rel="noopener noreferrer"
                className="border border-foreground/15 p-4 space-y-3 block hover:border-foreground/40 transition-all bg-background"
              >
                <div className="w-full aspect-video overflow-hidden">
                  <img
                    src={ideasLayerBanner}
                    alt={`Idea Layer ${n} banner`}
                    loading="lazy"
                    width={1024}
                    height={512}
                    className="w-full h-full object-cover"
                  />
                </div>
                <h3 className="text-xl font-bold">{title}</h3>
                <p className="text-base opacity-70">{uriDescription}</p>
                <p className="text-base opacity-70">
                  <span className="font-bold">Actions:</span> Stay tuned...
                </p>
              </a>
            ))}
          </div>
        </section>

        <hr className="border-foreground/15" />

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">At a glance</h2>
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "Treasury", value: "None" },
              { label: "Instances", value: "Multiple" },
              { label: "Autonomy", value: "Very high" },
              { label: "Primary Layer veto", value: "None" },
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
              { title: "A space for incubation", body: "The Idea Layer has no treasury and holds no financial assets. Its currency is social capital — ideas, knowledge, relationships, and engagement. This freedom from financial stakes makes it a low-pressure space to explore and develop cultural concepts without bureaucratic overhead." },
              { title: "The birthplace of Convergence Layers", body: "Only an Idea Layer can propose the creation of a new Convergence Layer. Members initiate the request, Assessors can veto it, and Ideas Stewards forward the proposal to the Primary Layer for final approval. No other part of the ecosystem has this power." },
              { title: "A gateway to the Primary Layer", body: "Active contributors in an Idea Layer can earn Election Tokens, which can be used to apply for membership of the Primary Layer. The Idea Layer acts as a talent pipeline — surfacing engaged participants and elevating them into the broader governance structure." },
              { title: "Highly self-governing", body: "Unlike other layers, the Idea Layer can adopt and revoke its own mandates without any veto from the Primary Layer. It defines who gets a voice, how discussions are moderated, and how it evolves — entirely from within." },
            ].map((c) => (
              <div key={c.title} className="border border-foreground/15 p-4">
                <h3 className="text-sm mb-1">{c.title}</h3>
                <p className="text-sm leading-relaxed opacity-70">{c.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="space-y-3">
          <h2 className="text-xs tracking-widest opacity-50 uppercase">Roles inside the Idea Layer</h2>
          <div className="border border-foreground/15">
            {[
              { name: "Ideas Participants", text: "Participants with voting rights. Membership is granted by Assessors following a public application. Ideas Participants can vote on proposals, nominate themselves for Ideas Steward elections, veto role changes, and apply for Primary Layer membership." },
              { name: "Assessors", text: "Appointed by Ideas Stewards to manage community standards and the membership process. They review applications, assign and revoke Ideas Participant roles, and can veto proposals to create a new Convergence Layer. They can also forward Primary Layer membership requests on behalf of Ideas Participants." },
              { name: "Ideas Stewards", text: "Elected from among Ideas Participants every 3 months — up to 3 at a time, for a maximum of 2 terms each. They lead the Idea Layer operationally: updating metadata, assigning Assessors, requesting new Convergence Layers, and executing mandate changes. No Ideas Steward exists at the point of creation — the first must be elected after launch." },
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
              { step: "Step 1", title: "Find a topic", body: "Browse the forum at enterhere.io and find an Idea Layer whose discussions interest you." },
              { step: "Step 2", title: "Apply", body: "Submit a public membership application. Any participant can apply — no tokens required to get started." },
              { step: "Step 3", title: "Get approved", body: "An Assessor reviews your application and assigns you the Ideas Participant role if approved." },
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
              { pill: "Election Token", text: "Awarded by Assessors to recognise active contributions. These cannot be exchanged for funds, but they carry real weight — they can be used to stand for Ideas Steward elections and to support an application for Primary Layer membership." },
              { pill: "Achievement Badge", text: "Issued when you are successfully elected into a role. It signals your accomplishment and also enforces term limits — ensuring no single participant can be elected to the same role more than twice." },
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
              <h3 className="text-sm mb-1">Ideas Participants can veto governance changes</h3>
              <p className="text-sm leading-relaxed opacity-70">When Ideas Stewards propose adopting new mandates, Ideas Participants have the right to veto — requiring a high threshold and quorum. This ensures the community retains meaningful control over how the Idea Layer governs itself.</p>
            </div>
            <div className="border border-foreground/15 p-4">
              <h3 className="text-sm mb-1">A Vote of No Confidence can reset leadership</h3>
              <p className="text-sm leading-relaxed opacity-70">If Ideas Participants collectively lose confidence in the elected Ideas Stewards, they can trigger a Vote of No Confidence to immediately revoke all Ideas Steward roles and launch a fresh election.</p>
            </div>
          </div>
        </section>

        <div className="border-l-2 border-foreground/40 pl-4 py-2">
          <p className="text-sm leading-relaxed opacity-80">
            <span className="font-bold">In short:</span> The Idea Layer is the most open and experimental part of the ecosystem. It costs nothing to join, holds no funds, and governs itself almost entirely from within. It is the place where cultural conversations start — and where the seeds of real-world events are planted.
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

export default IdeasDao;
