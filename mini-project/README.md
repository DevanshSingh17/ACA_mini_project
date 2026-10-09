---
https://github.com/DevanshSingh17/ACA_mini_project/tree/main/mini-project
## Design Comparison and Results

The project contains three matrix-multiplication architectures:

- **Design A:** Fully parallel reference design
- **Design B:** K-serial architecture
- **Design C:** K-serial architecture with double buffering

A detailed comparison of the architectures, synthesis results, cycle counts, stalls, and design trade-offs is available here:

### [ACA Mini-Project Report — Detailed Design Comparison](ACA_MiniProject_Report.pdf)
### [ACA Mini-Project Part 1 Report](ACA_MiniProject_Part1_Report_brief_3pages.pdf)

### Key Results

| Metric | Design A | Design B | Design C |
|---|---:|---:|---:|
| Multipliers | 64 | 16 | 16 |
| Cells | 113,160 | 62,151 | 113,160 |
| Logic Depth | 71 | 57 | 71 |
| Area × Delay | 8,034,360 | 3,542,607 | 8,034,360 |
| W1 Cycles | 40,961 | 53,249 | 41,729 |
| W2 Cycles | 299,009 | 397,313 | 299,777 |
| W1 Errors | 0 | 0 | 0 |
| W2 Errors | 0 | 0 | 0 |

All three designs passed the supplied workloads with zero errors.

### Design Summary

**Design A — Fully Parallel**

Uses 64 multipliers and computes all four K terms in one cycle. It provides the lowest computation latency but has the highest hardware cost.

**Design B — K-Serial**

Uses 16 multipliers and computes one K slice per cycle. A single `Mul` therefore requires four computation cycles. This significantly reduces hardware but increases execution time.

**Design C — K-Serial + Double Buffering**

Uses two A/B banks. While one bank is being computed, the other bank can be loaded with the next tile. This overlaps computation and loading and recovers most of the latency introduced by Design B.
