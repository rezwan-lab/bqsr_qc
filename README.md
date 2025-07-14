# 🧬 Complete Base Quality Score Recalibration (BQSR) Workflow: Before/After Quality Assessment using GATK

### 🔍 Problem: Why Does Base Quality Drop After BQSR?

While working on a variant calling pipeline, many researchers observe that running **FastQC** on BAM files *after* applying GATK’s `BaseRecalibrator` (BQSR) shows a noticeable **drop in per-base quality scores** compared to the original BAM (e.g., after `SplitNCigarReads`).

👉 **This drop is not an error — it's expected.**

---

### 🧠 What's Actually Happening?

- **Before BQSR**: Modern sequencers (e.g., Illumina) often **overestimate** base quality scores.
- **After BQSR**: Scores are recalibrated to reflect **true empirical accuracy**.
- ✅ **Result**: The recalibrated scores may look "lower," but they are more **accurate and reliable** for downstream analysis like variant calling.

---

### 📉 Why Does This Happen?

1. **Illumina Quality Binning**  
   Most Illumina platforms bin quality scores into just 4 levels, which leads to coarser estimates.

2. **Systematic Overestimation**  
   These bins tend to **overestimate the true sequencing accuracy**.

3. **BQSR Correction**  
   GATK’s BQSR uses known variants to estimate empirical error rates and adjusts base quality scores accordingly.

---

## 📊 The Science Behind BQSR

```
EXAMPLE:
BEFORE BQSR: Reported Q30 → Actual error rate = 1 in 500 (should be 1 in 1000)
             Quality was OVERESTIMATED by ~3 quality points

AFTER BQSR:  Reported Q27 → Actual error rate = 1 in 500  
             Quality is now ACCURATE - matches empirical data
```

**Key Insight**: "Quality Drop" is Actually Success.: If your post-BQSR FastQC shows reduced quality scores — it's good for download analysis
✅ The AnalyzeCovariates plot should show convergence between observed and predicted quality — that's your real success metric.

---

## 🧪 Pipeline Overview

```bash
Original BAM ─▶ [BaseRecalibrator] ─▶ BEFORE.table
       │
       └────▶ [ApplyBQSR] ─▶ Recalibrated BAM ─▶ [BaseRecalibrator] ─▶ AFTER.table
                                                          │
                                                          ▼
                                         [AnalyzeCovariates] → Comparison Plots


## 🧪 Workflow Overview

This SLURM-compatible script performs: Visualize the Effect of BQSR with a Complete 4-Step Workflow

1. `BaseRecalibrator` on original BAM → **Before table**
2. `ApplyBQSR` to recalibrate BAM → **Recalibrated BAM**
3. `BaseRecalibrator` on recalibrated BAM → **After table**
4. `AnalyzeCovariates` → **Plots and summary report**

---

## 🚀 Quick Start

### 1. Clone this repo

```bash
git clone https://github.com/yourusername/bqsr-qc.git
cd bqsr-qc
2. Edit 

scripts/bqsr_qc.sh

Modify inside the script:
ref_genome
dbsnp, known_indels, gold_standard_indels, etc.
original_bam
sample_name

3. Submit the job (SLURM)
bash
sbatch bqsr_qc.sh

