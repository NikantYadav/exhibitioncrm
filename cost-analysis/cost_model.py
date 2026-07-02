#!/usr/bin/env python3
"""
Pre-launch cost model for the Exono CRM.

Turns a go-to-market scenario (N teams, T reps/team, C cards/show-day, D show-days/mo,
plus a handful of adoption-rate assumptions) into every usage parameter and a full
monthly cost estimate.

This is the executable version of COSTS_PRELAUNCH_MODELING_GUIDE.md. Every number and
formula here traces back to that guide (which in turn follows INFRASTRUCTURE_ANALYSIS.md
and INFRASTRUCTURE_COSTS.md).

Run interactively:      python3 cost_model.py
Run with flags:         python3 cost_model.py --N 10 --T 10 --C 10 --D 4
Show the built-in       python3 cost_model.py --scenarios
  conservative/expected/aggressive bands

All monetary values are USD/month unless stated otherwise. Every constant is a knob you
can override on the command line -- run with -h to see them all.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field, asdict


# ---------------------------------------------------------------------------
# Constants -- vendor rates, free tiers, and per-unit sizes.
# The vendor rates / free tiers are FACTS (from pricing pages, June 2026).
# The per-unit sizes marked (PLAN-A) are ASSUMPTIONS -- measure them and override.
# ---------------------------------------------------------------------------

@dataclass
class Constants:
    # --- Per-unit sizes (PLAN-A: measure these locally, then override) ---
    avg_card_mb: float = 0.12          # post-compression card image size
    avg_attachment_mb: float = 2.0     # document-heavy chat attachment
    bytes_per_contact: int = 5000      # DB row + indexes + TOAST

    # --- Supabase (Pro) ---
    supabase_base: float = 25.0
    supabase_free_mau: int = 100_000
    supabase_rate_mau: float = 0.00325
    supabase_free_egress_gb: int = 250
    supabase_rate_egress: float = 0.09
    supabase_free_db_gb: int = 8
    supabase_rate_db: float = 0.125
    supabase_free_files_gb: int = 100
    supabase_rate_files: float = 0.021
    supabase_free_conns: int = 500
    supabase_rate_conns_per_1k: float = 10.0

    # --- Gemini (Flash-Lite) ---
    gemini_rate_in_per_1m: float = 0.10
    gemini_rate_out_per_1m: float = 0.40
    # Per-call token counts (PLAN-A: log usageMetadata, then override). Left at 0
    # by default so Gemini reports "measure tokens first" instead of a fake number.
    gemini_tokens_in_card: int = 0
    gemini_tokens_out_card: int = 0
    gemini_tokens_in_enrich: int = 0
    gemini_tokens_out_enrich: int = 0
    gemini_tokens_in_assistant: int = 0   # per message, summed over tool steps
    gemini_tokens_out_assistant: int = 0

    # --- Exa ---
    exa_free_searches: int = 20_000
    exa_rate_per_search: float = 0.007
    exa_searches_per_enrichment: float = 2.0

    # --- Deployment (single VPS, e.g. Hetzner CX22) ---
    vps_flat: float = 5.0

    # --- Sentry (replay is the one that bites) ---
    sentry_plan_fee: float = 26.0          # Team plan
    sentry_included_replays: int = 500
    sentry_rate_per_replay: float = 0.00375
    sentry_session_sample_rate: float = 1.0  # 1.0 = record every session (current code)

    # --- Fixed costs (from INFRASTRUCTURE_ANALYSIS.md), amortized to $/mo ---
    fixed_apple_per_year: float = 99.0
    fixed_domain_per_year: float = 200.0
    fixed_play_one_time: float = 25.0

    # --- Egress model ---
    egress_gb_per_user_per_mo: float = 0.1   # PLAN-A composed; replace after measuring

    # --- Modeling horizon ---
    months: int = 12                          # cumulative window for storage/DB


@dataclass
class AdoptionRates:
    """Soft assumptions not derivable from N/T/C/D. Defaults = guide 'expected'."""
    enrich_fraction_of_cards: float = 0.5     # half of scanned cards get enriched
    assistant_msgs_per_user_per_mo: float = 20.0
    attachments_per_user_per_mo: float = 2.0
    sessions_per_user_per_mo: float = 20.0
    peak_active_fraction: float = 0.70        # share of MAU online at busiest instant
    fraction_in_chat: float = 0.25            # share of those with a chat screen open


@dataclass
class Business:
    """Revenue, team/overhead cost, and unit-economics inputs.

    None of these come from the code -- they are YOUR startup's decisions.
    Defaults are illustrative placeholders; set them to your real plan.
    """
    # --- Pricing (two switchable models) ---
    pricing_model: str = "per_seat"           # "per_seat" | "per_team"
    price_per_user_per_mo: float = 30.0       # used when pricing_model == per_seat
    price_per_team_per_mo: float = 250.0      # used when pricing_model == per_team

    # --- Company overhead (monthly, not part of infra) ---
    monthly_salaries: float = 0.0             # founders + team payroll / mo
    other_fixed_opex: float = 0.0             # office, tools, legal, etc. / mo

    # --- Runway ---
    starting_capital: float = 0.0             # cash in the bank now

    # --- Unit economics ---
    monthly_churn_rate: float = 0.03          # fraction of customers lost per month
    cac_per_customer: float = 0.0             # cost to acquire one paying customer

    # Which "customer" the churn/CAC/LTV are counted in: "user" or "team".
    customer_unit: str = "user"


# ---------------------------------------------------------------------------
# The model
# ---------------------------------------------------------------------------

@dataclass
class Parameters:
    """Every derived usage number."""
    # scenario inputs (echoed back)
    N: int
    T: int
    C: float
    D: float
    # derived per-user / month
    mau: int
    cards_per_user_per_mo: float
    contacts_per_user_per_mo: float
    enrichments_per_user_per_mo: float
    assistant_msgs_per_user_per_mo: float
    attachments_per_user_per_mo: float
    sessions_per_user_per_mo: float
    # derived totals / month
    total_cards_per_mo: float
    total_contacts_per_mo: float
    total_enrichments_per_mo: float
    total_assistant_msgs_per_mo: float
    total_attachments_per_mo: float
    total_sessions_per_mo: float
    # realtime
    peak_concurrent_users: float
    peak_connections: float
    # cumulative storage/db (over `months`)
    gb_files: float
    gb_db: float
    gb_egress_per_mo: float
    exa_searches_per_mo: float


def derive_parameters(N, T, C, D, rates: AdoptionRates, k: Constants) -> Parameters:
    mau = N * T
    cards_per_user = C * D
    contacts_per_user = cards_per_user            # each card ~ one contact
    enrich_per_user = cards_per_user * rates.enrich_fraction_of_cards

    total_cards = mau * cards_per_user
    total_contacts = mau * contacts_per_user
    total_enrich = mau * enrich_per_user
    total_msgs = mau * rates.assistant_msgs_per_user_per_mo
    total_attach = mau * rates.attachments_per_user_per_mo
    total_sessions = mau * rates.sessions_per_user_per_mo

    peak_users = mau * rates.peak_active_fraction
    peak_conns = peak_users * (1 + rates.fraction_in_chat)

    # cumulative storage over the horizon (never shrinks)
    gb_files = (mau * k.months
                * (cards_per_user * k.avg_card_mb
                   + rates.attachments_per_user_per_mo * k.avg_attachment_mb)
                / 1024)
    gb_db = (mau * contacts_per_user * k.bytes_per_contact * k.months) / 1e9

    gb_egress = mau * k.egress_gb_per_user_per_mo
    exa_searches = total_enrich * k.exa_searches_per_enrichment

    return Parameters(
        N=N, T=T, C=C, D=D,
        mau=mau,
        cards_per_user_per_mo=cards_per_user,
        contacts_per_user_per_mo=contacts_per_user,
        enrichments_per_user_per_mo=enrich_per_user,
        assistant_msgs_per_user_per_mo=rates.assistant_msgs_per_user_per_mo,
        attachments_per_user_per_mo=rates.attachments_per_user_per_mo,
        sessions_per_user_per_mo=rates.sessions_per_user_per_mo,
        total_cards_per_mo=total_cards,
        total_contacts_per_mo=total_contacts,
        total_enrichments_per_mo=total_enrich,
        total_assistant_msgs_per_mo=total_msgs,
        total_attachments_per_mo=total_attach,
        total_sessions_per_mo=total_sessions,
        peak_concurrent_users=peak_users,
        peak_connections=peak_conns,
        gb_files=gb_files,
        gb_db=gb_db,
        gb_egress_per_mo=gb_egress,
        exa_searches_per_mo=exa_searches,
    )


@dataclass
class Costs:
    fixed: float
    supabase: float
    gemini: float | None       # None => needs per-call token measurement
    exa: float
    deployment: float
    sentry: float
    firebase: float
    uxcam: float
    codemagic: float
    total_ex_gemini: float


def compute_costs(p: Parameters, k: Constants) -> Costs:
    # Fixed (amortized to $/mo; one-time Play spread over the horizon)
    fixed = (k.fixed_apple_per_year / 12
             + k.fixed_domain_per_year / 12
             + k.fixed_play_one_time / k.months)

    # Supabase
    supabase = (k.supabase_base
                + max(p.mau - k.supabase_free_mau, 0) * k.supabase_rate_mau
                + max(p.gb_egress_per_mo - k.supabase_free_egress_gb, 0) * k.supabase_rate_egress
                + max(p.gb_db - k.supabase_free_db_gb, 0) * k.supabase_rate_db
                + max(p.gb_files - k.supabase_free_files_gb, 0) * k.supabase_rate_files
                + max(p.peak_connections - k.supabase_free_conns, 0) / 1000 * k.supabase_rate_conns_per_1k)

    # Gemini -- only if per-call tokens have been provided
    have_tokens = any([k.gemini_tokens_in_card, k.gemini_tokens_out_card,
                       k.gemini_tokens_in_enrich, k.gemini_tokens_out_enrich,
                       k.gemini_tokens_in_assistant, k.gemini_tokens_out_assistant])
    if have_tokens:
        in_tokens = (p.total_cards_per_mo * k.gemini_tokens_in_card
                     + p.total_enrichments_per_mo * k.gemini_tokens_in_enrich
                     + p.total_assistant_msgs_per_mo * k.gemini_tokens_in_assistant)
        out_tokens = (p.total_cards_per_mo * k.gemini_tokens_out_card
                      + p.total_enrichments_per_mo * k.gemini_tokens_out_enrich
                      + p.total_assistant_msgs_per_mo * k.gemini_tokens_out_assistant)
        gemini = (in_tokens / 1e6 * k.gemini_rate_in_per_1m
                  + out_tokens / 1e6 * k.gemini_rate_out_per_1m)
    else:
        gemini = None

    # Exa
    exa = max(p.exa_searches_per_mo - k.exa_free_searches, 0) * k.exa_rate_per_search

    # Deployment (flat)
    deployment = k.vps_flat

    # Sentry (plan + replay; replays = sessions * sample rate)
    replays = p.total_sessions_per_mo * k.sentry_session_sample_rate
    sentry = (k.sentry_plan_fee
              + max(replays - k.sentry_included_replays, 0) * k.sentry_rate_per_replay)

    # These stay $0 at the volumes this app hits pre-launch
    firebase = 0.0
    uxcam = 0.0        # free to 3,000 sessions/mo, then recording stops (no auto-bill)
    codemagic = 0.0    # release-cadence driven, within free minutes

    total_ex_gemini = (fixed + supabase + exa + deployment
                       + sentry + firebase + uxcam + codemagic)

    return Costs(fixed=fixed, supabase=supabase, gemini=gemini, exa=exa,
                 deployment=deployment, sentry=sentry, firebase=firebase,
                 uxcam=uxcam, codemagic=codemagic, total_ex_gemini=total_ex_gemini)


# ---------------------------------------------------------------------------
# Startup financials -- revenue, P&L, break-even, runway, unit economics
# ---------------------------------------------------------------------------

@dataclass
class Financials:
    # revenue / P&L
    revenue: float
    infra_cost: float                 # everything from Costs (incl. Gemini if known)
    overhead_cost: float              # salaries + other fixed opex
    total_cost: float
    gross_profit: float               # revenue - infra (variable-ish cost of service)
    gross_margin_pct: float | None
    operating_profit: float           # revenue - total cost (incl. overhead)
    profit_per_user: float

    # break-even
    customers: int                    # count in the chosen customer_unit
    price_per_customer: float
    variable_cost_per_customer: float
    breakeven_customers: float | None       # customers to cover total cost at current price
    breakeven_price_per_customer: float | None  # price to break even at current customers

    # runway / burn
    monthly_burn: float               # positive = losing money/mo
    runway_months: float | None       # None => profitable (infinite) or no capital info

    # unit economics
    customer_lifetime_months: float | None
    ltv: float | None                 # gross-margin lifetime value per customer
    cac: float
    ltv_cac_ratio: float | None
    cac_payback_months: float | None

    gemini_known: bool


def compute_financials(p: Parameters, c: Costs, b: Business) -> Financials:
    infra = c.total_ex_gemini + (c.gemini or 0.0)
    gemini_known = c.gemini is not None

    # --- revenue ---
    if b.pricing_model == "per_team":
        customers = p.N
        price_per_customer = b.price_per_team_per_mo
    else:  # per_seat
        customers = p.mau
        price_per_customer = b.price_per_user_per_mo
    revenue = customers * price_per_customer

    # If unit-economics customer_unit differs from the pricing unit, translate.
    # For simplicity we count customers/ARPU in the pricing unit for P&L, and use
    # customer_unit only for churn/LTV/CAC framing.
    overhead = b.monthly_salaries + b.other_fixed_opex
    total_cost = infra + overhead
    gross_profit = revenue - infra
    operating_profit = revenue - total_cost
    gross_margin = (gross_profit / revenue * 100) if revenue > 0 else None
    profit_per_user = (operating_profit / p.mau) if p.mau > 0 else 0.0

    # --- break-even ---
    # Split infra into a rough fixed vs per-customer variable part for break-even math.
    # Fixed infra = the base/flat lines that don't scale with a marginal customer.
    fixed_infra = c.fixed + c.supabase + c.deployment + c.sentry + c.firebase + c.uxcam + c.codemagic
    variable_infra = c.exa + (c.gemini or 0.0)  # the parts that scale with usage
    var_cost_per_customer = (variable_infra / customers) if customers > 0 else 0.0
    fixed_total = fixed_infra + overhead

    contribution = price_per_customer - var_cost_per_customer
    if contribution > 0:
        breakeven_customers = fixed_total / contribution
    else:
        breakeven_customers = None  # can never break even at this price/variable cost
    breakeven_price = (total_cost / customers) if customers > 0 else None

    # --- runway / burn ---
    monthly_burn = -operating_profit  # positive if losing money
    if monthly_burn <= 0:
        runway_months = None          # profitable -> effectively infinite runway
    elif b.starting_capital > 0:
        runway_months = b.starting_capital / monthly_burn
    else:
        runway_months = 0.0

    # --- unit economics ---
    if b.monthly_churn_rate > 0:
        lifetime_months = 1.0 / b.monthly_churn_rate
    else:
        lifetime_months = None

    # gross margin per customer per month * lifetime
    gm_per_customer_per_mo = price_per_customer - var_cost_per_customer
    if lifetime_months is not None:
        ltv = gm_per_customer_per_mo * lifetime_months
    else:
        ltv = None
    ltv_cac = (ltv / b.cac_per_customer) if (ltv is not None and b.cac_per_customer > 0) else None
    if b.cac_per_customer > 0 and gm_per_customer_per_mo > 0:
        cac_payback = b.cac_per_customer / gm_per_customer_per_mo
    else:
        cac_payback = None

    return Financials(
        revenue=revenue, infra_cost=infra, overhead_cost=overhead, total_cost=total_cost,
        gross_profit=gross_profit, gross_margin_pct=gross_margin,
        operating_profit=operating_profit, profit_per_user=profit_per_user,
        customers=customers, price_per_customer=price_per_customer,
        variable_cost_per_customer=var_cost_per_customer,
        breakeven_customers=breakeven_customers, breakeven_price_per_customer=breakeven_price,
        monthly_burn=monthly_burn, runway_months=runway_months,
        customer_lifetime_months=lifetime_months, ltv=ltv, cac=b.cac_per_customer,
        ltv_cac_ratio=ltv_cac, cac_payback_months=cac_payback,
        gemini_known=gemini_known,
    )


# ---------------------------------------------------------------------------
# Sweep -- recompute the model across a range of MAU (for charts)
# ---------------------------------------------------------------------------

def sweep_over_mau(base_p: Parameters, k: Constants, rates: AdoptionRates,
                   b: Business, max_mau: int, points: int = 40):
    """Vary MAU from ~0 up to max_mau, holding per-user behaviour fixed, and
    return parallel lists of (mau, revenue, total_cost, operating_profit).

    MAU is swept by scaling the number of teams while keeping reps/team, C and D
    fixed -- so per-user rates and per-user cost are held constant, exactly the
    'what if we sign more teams?' question a founder asks.
    """
    if max_mau < 1:
        max_mau = 1
    per_team = base_p.T if base_p.T else 1
    maus, revs, costs, profits = [], [], [], []
    for i in range(1, points + 1):
        mau = max(per_team, round(max_mau * i / points))
        n_teams = max(1, round(mau / per_team))
        p = derive_parameters(n_teams, base_p.T, base_p.C, base_p.D, rates, k)
        c = compute_costs(p, k)
        f = compute_financials(p, c, b)
        maus.append(p.mau)
        revs.append(round(f.revenue, 2))
        costs.append(round(f.total_cost, 2))
        profits.append(round(f.operating_profit, 2))
    return maus, revs, costs, profits


# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------

def _fmt_money(x):
    return "measure tokens first" if x is None else f"${x:,.2f}"


def print_report(p: Parameters, c: Costs, k: Constants):
    line = "=" * 60
    print(line)
    print(f"SCENARIO:  N={p.N} teams x T={p.T} reps  |  "
          f"C={p.C} cards/show-day x D={p.D} show-days/mo  |  horizon={k.months} mo")
    print(line)

    print("\n-- DERIVED PARAMETERS ------------------------------------")
    print(f"  MAU (N x T)                        {p.mau:>12,}")
    print("  per user / month:")
    print(f"    cards scanned                    {p.cards_per_user_per_mo:>12,.1f}")
    print(f"    contacts created                 {p.contacts_per_user_per_mo:>12,.1f}")
    print(f"    enrichments                      {p.enrichments_per_user_per_mo:>12,.1f}")
    print(f"    assistant messages               {p.assistant_msgs_per_user_per_mo:>12,.1f}")
    print(f"    chat attachments                 {p.attachments_per_user_per_mo:>12,.1f}")
    print(f"    sessions (app opens)             {p.sessions_per_user_per_mo:>12,.1f}")
    print("  totals / month:")
    print(f"    cards scanned                    {p.total_cards_per_mo:>12,.0f}")
    print(f"    contacts created                 {p.total_contacts_per_mo:>12,.0f}")
    print(f"    enrichments                      {p.total_enrichments_per_mo:>12,.0f}")
    print(f"    assistant messages               {p.total_assistant_msgs_per_mo:>12,.0f}")
    print(f"    chat attachments                 {p.total_attachments_per_mo:>12,.0f}")
    print(f"    sessions                         {p.total_sessions_per_mo:>12,.0f}")
    print(f"    exa searches                     {p.exa_searches_per_mo:>12,.0f}")
    print("  realtime:")
    print(f"    peak concurrent users            {p.peak_concurrent_users:>12,.1f}")
    print(f"    peak connections                 {p.peak_connections:>12,.1f}   (cap {k.supabase_free_conns})")
    print(f"  cumulative over {k.months} months:")
    print(f"    GB stored (files)                {p.gb_files:>12,.2f}   (free {k.supabase_free_files_gb})")
    print(f"    GB database                      {p.gb_db:>12,.2f}   (free {k.supabase_free_db_gb})")
    print(f"    GB egress / month                {p.gb_egress_per_mo:>12,.2f}   (free {k.supabase_free_egress_gb})")

    print("\n-- MONTHLY COST BREAKDOWN --------------------------------")
    print(f"    Fixed (Apple+domain+Play amort.) {_fmt_money(c.fixed):>20}")
    print(f"    Supabase                         {_fmt_money(c.supabase):>20}")
    print(f"    Deployment (single VPS)          {_fmt_money(c.deployment):>20}")
    print(f"    Exa                              {_fmt_money(c.exa):>20}")
    print(f"    Sentry (plan + replay)           {_fmt_money(c.sentry):>20}")
    print(f"    Firebase                         {_fmt_money(c.firebase):>20}")
    print(f"    UXCam                            {_fmt_money(c.uxcam):>20}")
    print(f"    Codemagic                        {_fmt_money(c.codemagic):>20}")
    print(f"    Gemini                           {_fmt_money(c.gemini):>20}")
    print("    " + "-" * 52)
    total = c.total_ex_gemini + (c.gemini or 0.0)
    if c.gemini is None:
        print(f"    TOTAL (ex-Gemini)                {_fmt_money(c.total_ex_gemini):>20}")
        print("    (add Gemini once per-call tokens are logged; see --help)")
    else:
        print(f"    TOTAL                            {_fmt_money(total):>20}")
    print(line)


def _fmt_num(x, unit=""):
    if x is None:
        return "n/a"
    return f"{x:,.1f}{unit}"


def print_financials(p: Parameters, f: Financials, b: Business, k: Constants):
    line = "=" * 60
    print("\n-- STARTUP FINANCIALS ------------------------------------")
    model = "per seat" if b.pricing_model == "per_seat" else "per team"
    print(f"  pricing model                      {model} @ ${f.price_per_customer:,.2f}/{'user' if b.pricing_model=='per_seat' else 'team'}/mo")
    print(f"  paying customers ({('users' if b.pricing_model=='per_seat' else 'teams')})            {f.customers:>12,}")
    print("\n  P&L (monthly):")
    print(f"    Revenue                          {_fmt_money(f.revenue):>20}")
    print(f"    Infra cost                       {_fmt_money(f.infra_cost):>20}"
          + ("" if f.gemini_known else "  (ex-Gemini)"))
    print(f"    Overhead (salaries + opex)       {_fmt_money(f.overhead_cost):>20}")
    print(f"    Total cost                       {_fmt_money(f.total_cost):>20}")
    print(f"    Gross profit (rev - infra)       {_fmt_money(f.gross_profit):>20}")
    gm = "n/a" if f.gross_margin_pct is None else f"{f.gross_margin_pct:,.1f}%"
    print(f"    Gross margin                     {gm:>20}")
    print(f"    Operating profit (rev - total)   {_fmt_money(f.operating_profit):>20}")
    print(f"    Profit per user / mo             {_fmt_money(f.profit_per_user):>20}")

    print("\n  Break-even:")
    print(f"    Variable cost per customer       {_fmt_money(f.variable_cost_per_customer):>20}")
    be = "never (price <= variable cost)" if f.breakeven_customers is None else f"{f.breakeven_customers:,.1f}"
    print(f"    Customers to break even          {be:>20}")
    print(f"    Break-even price / customer      {_fmt_money(f.breakeven_price_per_customer):>20}")

    print("\n  Runway & burn:")
    if f.monthly_burn <= 0:
        print(f"    Monthly result                   profitable (+{_fmt_money(-f.monthly_burn)}/mo)")
        print(f"    Runway                           infinite (cash-flow positive)")
    else:
        print(f"    Monthly burn                     {_fmt_money(f.monthly_burn):>20}")
        if b.starting_capital > 0:
            print(f"    Starting capital                 {_fmt_money(b.starting_capital):>20}")
            print(f"    Runway                           {_fmt_num(f.runway_months, ' months'):>20}")
        else:
            print(f"    Runway                           (set --capital to compute)")

    print("\n  Unit economics:")
    print(f"    Monthly churn                    {b.monthly_churn_rate*100:,.1f}%")
    print(f"    Customer lifetime                {_fmt_num(f.customer_lifetime_months, ' months'):>20}")
    print(f"    LTV (gross-margin)               {_fmt_money(f.ltv):>20}")
    print(f"    CAC                              {_fmt_money(f.cac):>20}")
    ratio = "n/a (set --cac)" if f.ltv_cac_ratio is None else f"{f.ltv_cac_ratio:,.2f} : 1"
    print(f"    LTV : CAC                        {ratio:>20}")
    print(f"    CAC payback                      {_fmt_num(f.cac_payback_months, ' months'):>20}")
    if f.ltv_cac_ratio is not None:
        verdict = ("healthy (>=3)" if f.ltv_cac_ratio >= 3
                   else "thin (aim for >=3)" if f.ltv_cac_ratio >= 1
                   else "unsustainable (<1)")
        print(f"    -> {verdict}")
    print(line)


# Built-in three-scenario bands from the guide (§1)
SCENARIOS = {
    "conservative": dict(N=2,  T=10, C=6,  D=2,
                         rates=AdoptionRates(assistant_msgs_per_user_per_mo=5,
                                             attachments_per_user_per_mo=0.5,
                                             sessions_per_user_per_mo=8,
                                             peak_active_fraction=0.60,
                                             fraction_in_chat=0.20)),
    "expected":     dict(N=10, T=10, C=10, D=4,
                         rates=AdoptionRates()),  # defaults
    "aggressive":   dict(N=40, T=10, C=15, D=6,
                         rates=AdoptionRates(assistant_msgs_per_user_per_mo=60,
                                             attachments_per_user_per_mo=5,
                                             sessions_per_user_per_mo=40,
                                             peak_active_fraction=0.80,
                                             fraction_in_chat=0.40)),
}


def build_argparser():
    ap = argparse.ArgumentParser(
        description="Pre-launch cost model. Enter your go-to-market scenario; "
                    "get every usage parameter and a monthly cost estimate.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    # scenario
    ap.add_argument("--N", type=int, help="number of teams signed")
    ap.add_argument("--T", type=int, help="reps per team")
    ap.add_argument("--C", type=float, help="cards scanned per show-day per rep")
    ap.add_argument("--D", type=float, help="show-days per month per rep")
    # adoption rates
    ap.add_argument("--enrich-fraction", type=float, default=0.5,
                    help="fraction of scanned cards that get enriched")
    ap.add_argument("--assistant-msgs", type=float, default=20.0,
                    help="assistant messages per user per month")
    ap.add_argument("--attachments", type=float, default=2.0,
                    help="chat attachments per user per month")
    ap.add_argument("--sessions", type=float, default=20.0,
                    help="app opens (sessions) per user per month")
    ap.add_argument("--peak-active", type=float, default=0.70,
                    help="fraction of MAU online at the busiest instant")
    ap.add_argument("--chat-fraction", type=float, default=0.25,
                    help="fraction of concurrent users with a chat screen open")
    # key constants worth overriding
    ap.add_argument("--months", type=int, default=12, help="modeling horizon (months)")
    ap.add_argument("--avg-card-mb", type=float, default=0.12,
                    help="avg stored card image size (MB) -- MEASURE this (PLAN-A)")
    ap.add_argument("--avg-attachment-mb", type=float, default=2.0,
                    help="avg chat attachment size (MB) -- MEASURE this (PLAN-A)")
    ap.add_argument("--sentry-sample", type=float, default=1.0,
                    help="Sentry replay sessionSampleRate (1.0=every session)")
    # Gemini per-call tokens (PLAN-A): supply to get a Gemini dollar figure
    ap.add_argument("--tokens-card", type=int, nargs=2, metavar=("IN", "OUT"),
                    help="Gemini tokens per card scan: IN OUT")
    ap.add_argument("--tokens-enrich", type=int, nargs=2, metavar=("IN", "OUT"),
                    help="Gemini tokens per enrichment: IN OUT")
    ap.add_argument("--tokens-assistant", type=int, nargs=2, metavar=("IN", "OUT"),
                    help="Gemini tokens per assistant message (summed over steps): IN OUT")
    # --- business / financials ---
    ap.add_argument("--pricing", choices=["per_seat", "per_team"], default="per_seat",
                    help="revenue model")
    ap.add_argument("--price-per-user", type=float, default=30.0,
                    help="$/user/mo (per_seat model)")
    ap.add_argument("--price-per-team", type=float, default=250.0,
                    help="$/team/mo (per_team model)")
    ap.add_argument("--salaries", type=float, default=0.0,
                    help="monthly salaries / payroll")
    ap.add_argument("--opex", type=float, default=0.0,
                    help="other monthly fixed opex (office, tools, legal)")
    ap.add_argument("--capital", type=float, default=0.0,
                    help="starting capital in the bank (for runway)")
    ap.add_argument("--churn", type=float, default=0.03,
                    help="monthly churn rate (0.03 = 3%%)")
    ap.add_argument("--cac", type=float, default=0.0,
                    help="customer acquisition cost per customer")

    # modes
    ap.add_argument("--scenarios", action="store_true",
                    help="print the built-in conservative/expected/aggressive bands and exit")
    ap.add_argument("--no-financials", action="store_true",
                    help="skip the startup-financials section")
    return ap


def business_from_args(a) -> Business:
    return Business(pricing_model=a.pricing,
                    price_per_user_per_mo=a.price_per_user,
                    price_per_team_per_mo=a.price_per_team,
                    monthly_salaries=a.salaries,
                    other_fixed_opex=a.opex,
                    starting_capital=a.capital,
                    monthly_churn_rate=a.churn,
                    cac_per_customer=a.cac,
                    customer_unit=("team" if a.pricing == "per_team" else "user"))


def constants_from_args(a) -> Constants:
    k = Constants(months=a.months,
                  avg_card_mb=a.avg_card_mb,
                  avg_attachment_mb=a.avg_attachment_mb,
                  sentry_session_sample_rate=a.sentry_sample)
    if a.tokens_card:
        k.gemini_tokens_in_card, k.gemini_tokens_out_card = a.tokens_card
    if a.tokens_enrich:
        k.gemini_tokens_in_enrich, k.gemini_tokens_out_enrich = a.tokens_enrich
    if a.tokens_assistant:
        k.gemini_tokens_in_assistant, k.gemini_tokens_out_assistant = a.tokens_assistant
    return k


def rates_from_args(a) -> AdoptionRates:
    return AdoptionRates(enrich_fraction_of_cards=a.enrich_fraction,
                         assistant_msgs_per_user_per_mo=a.assistant_msgs,
                         attachments_per_user_per_mo=a.attachments,
                         sessions_per_user_per_mo=a.sessions,
                         peak_active_fraction=a.peak_active,
                         fraction_in_chat=a.chat_fraction)


def prompt_int(label, default=None):
    suffix = f" [{default}]" if default is not None else ""
    while True:
        raw = input(f"{label}{suffix}: ").strip()
        if not raw and default is not None:
            return default
        try:
            return type(default)(raw) if default is not None else float(raw)
        except ValueError:
            print("  please enter a number.")


def main():
    a = build_argparser().parse_args()

    if a.scenarios:
        for name, cfg in SCENARIOS.items():
            k = Constants(months=a.months, sentry_session_sample_rate=a.sentry_sample)
            p = derive_parameters(cfg["N"], cfg["T"], cfg["C"], cfg["D"], cfg["rates"], k)
            c = compute_costs(p, k)
            print(f"\n########## {name.upper()} ##########")
            print_report(p, c, k)
        return

    # interactive prompts for any of N/T/C/D not passed on the command line
    if a.N is None:
        print("Enter your go-to-market scenario (press Enter to accept the default):\n")
        a.N = prompt_int("Teams signed (N)", 10)
        a.T = prompt_int("Reps per team (T)", 10)
        a.C = prompt_int("Cards per show-day per rep (C)", 10.0)
        a.D = prompt_int("Show-days per month per rep (D)", 4.0)
    else:
        # fill any individually-missing ones with sensible defaults
        a.T = a.T if a.T is not None else 10
        a.C = a.C if a.C is not None else 10.0
        a.D = a.D if a.D is not None else 4.0

    k = constants_from_args(a)
    rates = rates_from_args(a)
    p = derive_parameters(a.N, a.T, a.C, a.D, rates, k)
    c = compute_costs(p, k)
    print()
    print_report(p, c, k)
    if not a.no_financials:
        b = business_from_args(a)
        f = compute_financials(p, c, b)
        print_financials(p, f, b, k)


if __name__ == "__main__":
    main()
