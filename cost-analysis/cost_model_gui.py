#!/usr/bin/env python3
"""
Modern web GUI for the pre-launch cost & startup-finance model.

Built with NiceGUI. Imports the calculation engine from cost_model.py so the CLI
and GUI always agree. Run:

    env/bin/python cost_model_gui.py

then open http://localhost:8080 (it opens automatically in native mode).

Left panel: your inputs, in four groups --
  1. Scenario (N, T, C, D)
  2. Adoption rates (the soft assumptions)
  3. PLAN-A measured values (per-unit costs you measured locally + Gemini tokens)
  4. Business (pricing, overhead, capital, churn, CAC)
Right panel: live cost breakdown + startup financials, recomputed on every change.
"""

from __future__ import annotations

from nicegui import ui

import cost_model as cm


# ---------------------------------------------------------------------------
# State -- one dict holding every input; the UI binds to it and recomputes.
# ---------------------------------------------------------------------------

state = {
    # scenario
    "N": 10, "T": 10, "C": 10.0, "D": 4.0,
    # adoption
    "enrich_fraction": 0.5,
    "assistant_msgs": 20.0,
    "attachments": 2.0,
    "sessions": 20.0,
    "peak_active": 0.70,
    "chat_fraction": 0.25,
    # PLAN-A per-unit
    "avg_card_mb": 0.12,
    "avg_attachment_mb": 2.0,
    "bytes_per_contact": 5000,
    "egress_per_user": 0.10,
    "months": 12,
    "sentry_sample": 1.0,
    # Gemini tokens (0 = unknown -> "measure first")
    "tok_card_in": 0, "tok_card_out": 0,
    "tok_enrich_in": 0, "tok_enrich_out": 0,
    "tok_asst_in": 0, "tok_asst_out": 0,
    # business
    "pricing": "per_seat",
    "price_per_user": 30.0,
    "price_per_team": 250.0,
    "salaries": 8000.0,
    "opex": 0.0,
    "capital": 100000.0,
    "churn": 0.03,
    "cac": 200.0,
}


def build_models():
    s = state
    k = cm.Constants(
        avg_card_mb=s["avg_card_mb"],
        avg_attachment_mb=s["avg_attachment_mb"],
        bytes_per_contact=int(s["bytes_per_contact"]),
        egress_gb_per_user_per_mo=s["egress_per_user"],
        months=int(s["months"]),
        sentry_session_sample_rate=s["sentry_sample"],
        gemini_tokens_in_card=int(s["tok_card_in"]),
        gemini_tokens_out_card=int(s["tok_card_out"]),
        gemini_tokens_in_enrich=int(s["tok_enrich_in"]),
        gemini_tokens_out_enrich=int(s["tok_enrich_out"]),
        gemini_tokens_in_assistant=int(s["tok_asst_in"]),
        gemini_tokens_out_assistant=int(s["tok_asst_out"]),
    )
    rates = cm.AdoptionRates(
        enrich_fraction_of_cards=s["enrich_fraction"],
        assistant_msgs_per_user_per_mo=s["assistant_msgs"],
        attachments_per_user_per_mo=s["attachments"],
        sessions_per_user_per_mo=s["sessions"],
        peak_active_fraction=s["peak_active"],
        fraction_in_chat=s["chat_fraction"],
    )
    biz = cm.Business(
        pricing_model=s["pricing"],
        price_per_user_per_mo=s["price_per_user"],
        price_per_team_per_mo=s["price_per_team"],
        monthly_salaries=s["salaries"],
        other_fixed_opex=s["opex"],
        starting_capital=s["capital"],
        monthly_churn_rate=s["churn"],
        cac_per_customer=s["cac"],
        customer_unit=("team" if s["pricing"] == "per_team" else "user"),
    )
    p = cm.derive_parameters(int(s["N"]), int(s["T"]), s["C"], s["D"], rates, k)
    c = cm.compute_costs(p, k)
    f = cm.compute_financials(p, c, biz)
    return k, p, c, f, biz


def money(x):
    return "measure tokens first" if x is None else f"${x:,.2f}"


def money0(x):
    return "n/a" if x is None else f"${x:,.0f}"


def num(x, unit=""):
    return "n/a" if x is None else f"{x:,.1f}{unit}"


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

ui.colors(primary="#2563eb")
ui.add_head_html("<style>body{background:#0f172a}</style>")


def input_number(label, key, step=1.0, fmt=None, suffix=None, min=0):
    e = ui.number(label=label, value=state[key], step=step, min=min,
                  format=fmt).props("dense outlined").classes("w-full")
    if suffix:
        e.props(f'suffix="{suffix}"')

    def on_change(ev):
        try:
            state[key] = ev.value if ev.value is not None else 0
        except Exception:
            pass
        refresh()
    e.on_value_change(on_change)
    return e


with ui.row().classes("w-full no-wrap gap-4 p-4"):

    # ---------------- LEFT: inputs ----------------
    with ui.column().classes("gap-3").style("width: 420px; min-width: 420px"):
        ui.label("Exono CRM — Cost & Startup Model").classes("text-2xl font-bold text-white")
        ui.label("Every number recomputes live. Replace defaults with your plan "
                 "and your PLAN-A measurements.").classes("text-xs text-slate-400")

        with ui.expansion("1 · Go-to-market scenario", value=True).classes("w-full text-white bg-slate-800 rounded"):
            with ui.column().classes("w-full gap-2 p-2"):
                input_number("Teams signed (N)", "N", step=1)
                input_number("Reps per team (T)", "T", step=1)
                input_number("Cards per show-day (C)", "C", step=1)
                input_number("Show-days per month (D)", "D", step=1)

        with ui.expansion("2 · Adoption rates (assumptions)").classes("w-full text-white bg-slate-800 rounded"):
            with ui.column().classes("w-full gap-2 p-2"):
                input_number("Enrich fraction of cards", "enrich_fraction", step=0.05)
                input_number("Assistant msgs / user / mo", "assistant_msgs", step=1)
                input_number("Attachments / user / mo", "attachments", step=0.5)
                input_number("Sessions / user / mo", "sessions", step=1)
                input_number("Peak active fraction", "peak_active", step=0.05)
                input_number("Fraction in chat", "chat_fraction", step=0.05)

        with ui.expansion("3 · PLAN-A measured values").classes("w-full text-white bg-slate-800 rounded"):
            with ui.column().classes("w-full gap-2 p-2"):
                ui.label("Per-unit sizes you measured locally").classes("text-xs text-slate-400")
                input_number("Avg card image (MB)", "avg_card_mb", step=0.01)
                input_number("Avg attachment (MB)", "avg_attachment_mb", step=0.1)
                input_number("Bytes per contact", "bytes_per_contact", step=500)
                input_number("Egress GB / user / mo", "egress_per_user", step=0.01)
                input_number("Modeling horizon (months)", "months", step=1)
                input_number("Sentry replay sample rate", "sentry_sample", step=0.05)
                ui.separator()
                ui.label("Gemini tokens per call (0 = unknown)").classes("text-xs text-slate-400")
                with ui.row().classes("w-full no-wrap gap-2"):
                    input_number("card in", "tok_card_in", step=100)
                    input_number("card out", "tok_card_out", step=100)
                with ui.row().classes("w-full no-wrap gap-2"):
                    input_number("enrich in", "tok_enrich_in", step=100)
                    input_number("enrich out", "tok_enrich_out", step=100)
                with ui.row().classes("w-full no-wrap gap-2"):
                    input_number("asst in", "tok_asst_in", step=100)
                    input_number("asst out", "tok_asst_out", step=100)

        with ui.expansion("4 · Business & financials").classes("w-full text-white bg-slate-800 rounded"):
            with ui.column().classes("w-full gap-2 p-2"):
                toggle = ui.toggle({"per_seat": "Per seat", "per_team": "Per team"},
                                   value=state["pricing"]).props("dense")

                def on_pricing(ev):
                    state["pricing"] = ev.value
                    refresh()
                toggle.on_value_change(on_pricing)
                input_number("Price / user / mo ($)", "price_per_user", step=1)
                input_number("Price / team / mo ($)", "price_per_team", step=10)
                input_number("Monthly salaries ($)", "salaries", step=500)
                input_number("Other opex / mo ($)", "opex", step=100)
                input_number("Starting capital ($)", "capital", step=5000)
                input_number("Monthly churn (0.03=3%)", "churn", step=0.005)
                input_number("CAC per customer ($)", "cac", step=25)

        with ui.row().classes("w-full gap-2"):
            ui.button("Load conservative", on_click=lambda: load_scenario("conservative")).props("outline size=sm")
            ui.button("Expected", on_click=lambda: load_scenario("expected")).props("outline size=sm")
            ui.button("Aggressive", on_click=lambda: load_scenario("aggressive")).props("outline size=sm")

    # ---------------- RIGHT: results ----------------
    results = ui.column().classes("gap-4 flex-grow")


# ---------------------------------------------------------------------------
# Scenario presets (mirror cost_model.SCENARIOS)
# ---------------------------------------------------------------------------

def load_scenario(name):
    presets = {
        "conservative": dict(N=2, T=10, C=6, D=2, assistant_msgs=5, attachments=0.5,
                             sessions=8, peak_active=0.60, chat_fraction=0.20),
        "expected":     dict(N=10, T=10, C=10, D=4, assistant_msgs=20, attachments=2,
                             sessions=20, peak_active=0.70, chat_fraction=0.25),
        "aggressive":   dict(N=40, T=10, C=15, D=6, assistant_msgs=60, attachments=5,
                             sessions=40, peak_active=0.80, chat_fraction=0.40),
    }
    state.update(presets[name])
    rebuild_inputs()
    refresh()


def rebuild_inputs():
    # Simplest way to reflect preset values back into the number widgets is a reload.
    ui.navigate.reload()


# ---------------------------------------------------------------------------
# Rendering the results panel
# ---------------------------------------------------------------------------

def stat_card(title, rows, accent="#1e293b"):
    with ui.card().classes("w-full").style(f"background:{accent}"):
        ui.label(title).classes("text-sm font-bold text-slate-300 uppercase tracking-wide")
        with ui.grid(columns=2).classes("w-full gap-x-4 gap-y-1"):
            for label, value, *rest in rows:
                color = rest[0] if rest else "text-white"
                ui.label(label).classes("text-sm text-slate-400")
                ui.label(str(value)).classes(f"text-sm text-right font-mono {color}")


def refresh():
    k, p, c, f, biz = build_models()
    results.clear()
    with results:
        # headline row
        op = f.operating_profit
        prof_color = "text-emerald-400" if op >= 0 else "text-rose-400"
        with ui.row().classes("w-full no-wrap gap-4"):
            with ui.card().classes("flex-grow").style("background:#1e293b"):
                ui.label("MAU").classes("text-xs text-slate-400 uppercase")
                ui.label(f"{p.mau:,}").classes("text-3xl font-bold text-white")
            with ui.card().classes("flex-grow").style("background:#1e293b"):
                ui.label("Revenue / mo").classes("text-xs text-slate-400 uppercase")
                ui.label(money0(f.revenue)).classes("text-3xl font-bold text-sky-400")
            with ui.card().classes("flex-grow").style("background:#1e293b"):
                ui.label("Operating profit / mo").classes("text-xs text-slate-400 uppercase")
                ui.label(money0(op)).classes(f"text-3xl font-bold {prof_color}")
            with ui.card().classes("flex-grow").style("background:#1e293b"):
                ui.label("Runway").classes("text-xs text-slate-400 uppercase")
                rtxt = "∞" if f.runway_months is None else f"{f.runway_months:,.0f} mo"
                ui.label(rtxt).classes("text-3xl font-bold text-amber-400")

        with ui.row().classes("w-full no-wrap gap-4 items-start"):
            with ui.column().classes("flex-grow gap-4"):
                stat_card("Cost breakdown / mo", [
                    ("Fixed (Apple+domain+Play)", money(c.fixed)),
                    ("Supabase", money(c.supabase)),
                    ("Deployment (VPS)", money(c.deployment)),
                    ("Exa", money(c.exa)),
                    ("Sentry (plan+replay)", money(c.sentry)),
                    ("Gemini", money(c.gemini),
                     "text-white" if c.gemini is not None else "text-amber-400"),
                    ("Firebase / UXCam / Codemagic", "$0.00"),
                    ("TOTAL infra", money(f.infra_cost) + ("" if f.gemini_known else " *"),
                     "text-sky-300 font-bold"),
                ])
                stat_card("Derived parameters", [
                    ("Cards / user / mo", num(p.cards_per_user_per_mo)),
                    ("Total cards / mo", f"{p.total_cards_per_mo:,.0f}"),
                    ("Enrichments / mo", f"{p.total_enrichments_per_mo:,.0f}"),
                    ("Assistant msgs / mo", f"{p.total_assistant_msgs_per_mo:,.0f}"),
                    ("Sessions / mo", f"{p.total_sessions_per_mo:,.0f}"),
                    ("Exa searches / mo", f"{p.exa_searches_per_mo:,.0f}"),
                    ("Peak connections", f"{p.peak_connections:,.0f} / {k.supabase_free_conns}"),
                    ("GB files (cum.)", num(p.gb_files, f" / {k.supabase_free_files_gb}")),
                    ("GB database (cum.)", num(p.gb_db, f" / {k.supabase_free_db_gb}")),
                    ("GB egress / mo", num(p.gb_egress_per_mo, f" / {k.supabase_free_egress_gb}")),
                ])

            with ui.column().classes("flex-grow gap-4"):
                cust_unit = "users" if biz.pricing_model == "per_seat" else "teams"
                stat_card("P&L / mo", [
                    ("Revenue", money(f.revenue), "text-sky-300"),
                    ("Infra cost", money(f.infra_cost)),
                    ("Overhead", money(f.overhead_cost)),
                    ("Total cost", money(f.total_cost)),
                    ("Gross profit", money(f.gross_profit),
                     "text-emerald-400" if f.gross_profit >= 0 else "text-rose-400"),
                    ("Gross margin", "n/a" if f.gross_margin_pct is None else f"{f.gross_margin_pct:,.1f}%"),
                    ("Operating profit", money(f.operating_profit), prof_color),
                    ("Profit / user / mo", money(f.profit_per_user)),
                ])
                be_c = ("never" if f.breakeven_customers is None
                        else f"{f.breakeven_customers:,.0f} {cust_unit}")
                stat_card("Break-even", [
                    (f"Paying {cust_unit}", f"{f.customers:,}"),
                    ("Price / customer", money(f.price_per_customer)),
                    ("Variable cost / customer", money(f.variable_cost_per_customer)),
                    ("Customers to break even", be_c,
                     "text-emerald-400" if (f.breakeven_customers is not None
                                            and f.customers >= f.breakeven_customers)
                     else "text-amber-400"),
                    ("Break-even price / cust.", money(f.breakeven_price_per_customer)),
                ])
                ratio = ("n/a" if f.ltv_cac_ratio is None else f"{f.ltv_cac_ratio:,.2f} : 1")
                ratio_color = "text-white"
                if f.ltv_cac_ratio is not None:
                    ratio_color = ("text-emerald-400" if f.ltv_cac_ratio >= 3
                                   else "text-amber-400" if f.ltv_cac_ratio >= 1
                                   else "text-rose-400")
                stat_card("Unit economics", [
                    ("Monthly churn", f"{biz.monthly_churn_rate*100:,.1f}%"),
                    ("Customer lifetime", num(f.customer_lifetime_months, " mo")),
                    ("LTV (gross-margin)", money(f.ltv)),
                    ("CAC", money(f.cac)),
                    ("LTV : CAC", ratio, ratio_color),
                    ("CAC payback", num(f.cac_payback_months, " mo")),
                ])

        if not f.gemini_known:
            ui.label("* Infra total excludes Gemini — enter per-call token counts in "
                     "section 3 (PLAN-A) to include it.").classes("text-xs text-amber-400")


refresh()

if __name__ in {"__main__", "__mp_main__"}:
    ui.run(title="Exono Cost & Startup Model", native=False, port=8080,
           reload=False, show=False)
