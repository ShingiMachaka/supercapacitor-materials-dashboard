# How Synthesis Choices Drive Supercapacitor Performance

A MySQL database and Power BI dashboard built from 23 results in 14 peer-reviewed papers, showing how the way an electrode material is made changes how well it stores charge.

## Why I built this

My master's thesis at NUST MISIS (Moscow) studied the effect of polyaniline (PANI) on the electrochemical properties of supercapacitors. This project grew out of wanting to understand the wider field, and it brings that materials background together with my MS in Business Analytics & AI at American University. I deliberately kept it to 14 papers so I could learn the full pipeline end to end.

## Key findings

When only the synthesis changes (same paper, same electrolyte, same test):

- **Shape matters:** Fe₂O₃ nanorods reached **504 F/g**, 3.6× the capacitance of nanoparticles with the same composition.
- **Temperature matters:** charring coal at 1000 °C instead of 520 °C **more than halved** the capacitance of the resulting activated carbon (286 → 127 F/g).
- **Choices carry trade-offs:** polypyrrole grown on titanium gave **15% more capacitance** than on stainless steel, but **lower stability** (77% vs. 91% retention).

![Controlled comparisons page]

## What I built

- **Data extraction** from primary literature into a structured dataset
- **Normalized MySQL schema** (5 tables, enforced foreign keys) with a staging-and-load pipeline that handles blank values correctly
- **Power BI star-schema model** with DAX measures and a hidden validation page
- **Three-page dashboard:** a cross-paper overview, the controlled comparisons, and an explorer table tracing every result to its source

## Repository

```
data/      Cleaned dataset (CSV)
sql/       Build scripts, run in numeric order
powerbi/   Dashboard (.pbix) and PDF export
images/    Screenshots
```

No Power BI Desktop? Open `powerbi/supercapacitor_dashboard.pdf`.

**Tools:** MySQL · Power BI (Power Query, DAX) · Python

---

**Shingirai MacHaka** · [LinkedIn](https://www.linkedin.com/in/shingi-machaka/)
