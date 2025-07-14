#!/bin/bash
#SBATCH --job-name=complete_bqsr
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --time=48:00:00
#SBATCH --mem=64G
#SBATCH --partition=cpu
#SBATCH --output=complete_bqsr_%j.out
#SBATCH --error=complete_bqsr_%j.err

# Load modules
echo "Loading required modules..."
module load SAMtools
module load GATK

# Resources
echo "Setting up reference paths..."
ref_genome="/path_to_file/references/GRCh38.primary_assembly.genome.fa"
dbsnp="/path_to_file/references/Homo_sapiens_assembly38.dbsnp138.vcf"
known_indels="/path_to_file/references/Homo_sapiens_assembly38.known_indels.vcf.gz"
gold_standard_indels="/path_to_file/references/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
thousand_omni="/path_to_file/references/1000G_omni2.5.hg38.vcf.gz"
hapmap="/path_to_file/references/hapmap_3.3.hg38.vcf.gz"

# Input parameters
original_bam="/path_to_file/original.bam"  # ORIGINAL BAM FILE (before any recalibration)
output_dir="./bqsr_complete_analysis"
sample_name="sample1"

# Output directory
echo "Creating output directory: $output_dir"
mkdir -p "$output_dir"

# Set GATK command with memory settings
gatk_cmd="gatk --java-options '-Xmx60G -XX:+UseParallelGC -XX:ParallelGCThreads=8'"

echo "Starting COMPLETE BQSR pipeline..."
echo "================================================="
echo "This pipeline performs the full 4-step BQSR workflow:"
echo "1. Generate BEFORE recalibration table (from original BAM)"
echo "2. Apply recalibration to create recalibrated BAM"
echo "3. Generate AFTER recalibration table (from recalibrated BAM)"
echo "4. Compare before/after tables with plots"
echo "================================================="

# ===================================================================
# STEP 1: Generate "BEFORE" recalibration table from ORIGINAL BAM
# ===================================================================
echo ""
echo "STEP 1: Generate BEFORE recalibration table"
echo "-------------------------------------------"
echo "Input: Original BAM file (before any recalibration)"
echo "Output: BEFORE recalibration table"

before_table="${output_dir}/${sample_name}_BEFORE_recal.table"

echo "Running BaseRecalibrator on ORIGINAL BAM..."
$gatk_cmd BaseRecalibrator \
    -R "$ref_genome" \
    -I "$original_bam" \
    --known-sites "$dbsnp" \
    --known-sites "$known_indels" \
    --known-sites "$gold_standard_indels" \
    --known-sites "$thousand_omni" \
    --known-sites "$hapmap" \
    -O "$before_table"

if [[ $? -ne 0 ]]; then
    echo "ERROR: STEP 1 failed - BaseRecalibrator (before table)"
    exit 1
fi
echo "✓ STEP 1 completed: BEFORE table generated at $before_table"

# ===================================================================
# STEP 2: Apply recalibration to create recalibrated BAM
# ===================================================================
echo ""
echo "STEP 2: Apply recalibration to original BAM"
echo "--------------------------------------------"
echo "Input: Original BAM + BEFORE recalibration table"
echo "Output: Recalibrated BAM file"

recalibrated_bam="${output_dir}/${sample_name}_recalibrated.bam"

echo "Running ApplyBQSR to create recalibrated BAM..."
$gatk_cmd ApplyBQSR \
    -R "$ref_genome" \
    -I "$original_bam" \
    --bqsr-recal-file "$before_table" \
    -O "$recalibrated_bam"

if [[ $? -ne 0 ]]; then
    echo "ERROR: STEP 2 failed - ApplyBQSR"
    exit 1
fi
echo "✓ STEP 2 completed: Recalibrated BAM created at $recalibrated_bam"

# ===================================================================
# STEP 3: Generate "AFTER" recalibration table from recalibrated BAM
# ===================================================================
echo ""
echo "STEP 3: Generate AFTER recalibration table"
echo "-------------------------------------------"
echo "Input: Recalibrated BAM file"
echo "Output: AFTER recalibration table"

after_table="${output_dir}/${sample_name}_AFTER_recal.table"

echo "Running BaseRecalibrator on RECALIBRATED BAM..."
$gatk_cmd BaseRecalibrator \
    -R "$ref_genome" \
    -I "$recalibrated_bam" \
    --known-sites "$dbsnp" \
    --known-sites "$known_indels" \
    --known-sites "$gold_standard_indels" \
    --known-sites "$thousand_omni" \
    --known-sites "$hapmap" \
    -O "$after_table"

if [[ $? -ne 0 ]]; then
    echo "ERROR: STEP 3 failed - BaseRecalibrator (after table)"
    exit 1
fi
echo "✓ STEP 3 completed: AFTER table generated at $after_table"

# ===================================================================
# STEP 4: Compare BEFORE and AFTER tables to assess recalibration
# ===================================================================
echo ""
echo "STEP 4: Compare BEFORE and AFTER recalibration"
echo "-----------------------------------------------"
echo "Input: BEFORE table + AFTER table"
echo "Output: Recalibration comparison plots"

plots_file="${output_dir}/${sample_name}_recalibration_comparison.pdf"

echo "Running AnalyzeCovariates to compare BEFORE and AFTER..."
$gatk_cmd AnalyzeCovariates \
    -before "$before_table" \
    -after "$after_table" \
    -plots "$plots_file"

if [[ $? -ne 0 ]]; then
    echo "ERROR: STEP 4 failed - AnalyzeCovariates"
    exit 1
fi
echo "✓ STEP 4 completed: Comparison plots generated at $plots_file"

# ===================================================================
# GENERATE SUMMARY REPORT
# ===================================================================
echo ""
echo "Generating summary report..."
summary_file="${output_dir}/${sample_name}_BQSR_summary.txt"

cat > "$summary_file" << EOF
COMPLETE BQSR ANALYSIS SUMMARY
==============================
Generated on: $(date)
Sample: $sample_name

WORKFLOW OVERVIEW:
1. BaseRecalibrator (original BAM) → BEFORE table
2. ApplyBQSR (apply recalibration) → recalibrated BAM  
3. BaseRecalibrator (recalibrated BAM) → AFTER table
4. AnalyzeCovariates (compare tables) → comparison plots

INPUT FILES:
- Original BAM: $original_bam
- Reference genome: $ref_genome
- Known sites: dbSNP, known indels, gold standard, etc.

OUTPUT FILES:
- BEFORE recalibration table: $before_table
- Recalibrated BAM: $recalibrated_bam
- AFTER recalibration table: $after_table
- Comparison plots: $plots_file
- This summary: $summary_file

WHAT TO DO NEXT:
1. Review the comparison plots PDF to assess BQSR effectiveness
2. Look for convergence between before/after quality scores
3. If recalibration looks good, use the recalibrated BAM for variant calling
4. The recalibrated BAM should show improved base quality accuracy

INTERPRETATION:
- The plots should show that quality scores are more accurate after recalibration
- Look for flattening of the quality score distributions
- Residual errors should be minimal in the "after" plots
EOF

# Display final summary
echo ""
echo "================================================="
echo "COMPLETE BQSR PIPELINE FINISHED SUCCESSFULLY!"
echo "================================================="
echo ""
echo "GENERATED FILES:"
echo "1. BEFORE table: $before_table"
echo "2. Recalibrated BAM: $recalibrated_bam" 
echo "3. AFTER table: $after_table"
echo "4. Comparison plots: $plots_file"
echo "5. Summary report: $summary_file"
echo ""
echo "KEY POINT: The 'before' and 'after' tables are generated by running"
echo "BaseRecalibrator on the original BAM (before) and recalibrated BAM (after)."
echo ""
echo "Job completed at: $(date)"

# ===================================================================
# ALTERNATIVE: If already have existing files
# ===================================================================
echo ""
echo "================================================="
echo "ALTERNATIVE: Using existing files"
echo "================================================="
echo ""
echo "If already have:"
echo "- A recalibrated BAM: path_to_file/recalibration/sample_name.recal.bam"
echo "- A BEFORE table: path_to_file/recalibration/sample_name.recal_data.table"
echo ""
echo "Then only need to run STEP 3 and 4:"
echo ""
echo "# Generate AFTER table from existing recalibrated BAM:"
echo '$gatk_cmd BaseRecalibrator \'
echo '    -R "$ref_genome" \'
echo '    -I "path_to_file/recalibration/sample_name.recal.bam" \'
echo '    --known-sites "$dbsnp" \'
echo '    --known-sites "$known_indels" \'
echo '    --known-sites "$gold_standard_indels" \'
echo '    --known-sites "$thousand_omni" \'
echo '    --known-sites "$hapmap" \'
echo '    -O "./sample_name_AFTER_recal.table"'
echo ""
echo "# Compare existing BEFORE table with the new AFTER table:"
echo '$gatk_cmd AnalyzeCovariates \'
echo '    -before "path_to_file/recalibration/sample_name.recal_data.table" \'
echo '    -after "./sample_name_AFTER_recal.table" \'
echo '    -plots "./sample_name_comparison_plots.pdf"'

exit 0