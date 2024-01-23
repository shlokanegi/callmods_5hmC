version 1.0

workflow callmods_5hmC {
    meta {
        author: "Shloka Negi"
        email: "shnegi@ucsc.edu"
        description: "Generates high-confidence 5hmC mod calls using modkit,other stats and plots."
    }

    parameter_meta {
        MODBAM: "Assembled BAM file mapped to reference, containing modified base information. (Aligned and sorted)"
        MODBAM_INDEX: "MODBAM index file"
        SAMPLE: "Sample Name. Will be used in output file"
        REF: "Reference genome assembly to which the modbam was aligned."
        ML_HIST: "(OPTIONAL) Generate ML probability distribution stats and plots of bases/modbases ?? Default: false"
        GENOME_FILE: "(OPTIONAL) Genome file with chrs and lengths. Used to generate a genome-wide bedgraph file using high-confidence mods"
    }

    input {
        File MODBAM
        File MODBAM_INDEX
        String SAMPLE
        File REF
        Boolean ML_HIST = false
        File? GENOME_FILE
    }

    if (ML_HIST){
        call plot_ML_hist {
            input:
            modbam=MODBAM,
            modbam_index=MODBAM_INDEX,
            sample=SAMPLE
        }
    }

    call run_modkit {
        input:
        modbam=MODBAM,
        modbam_index=MODBAM_INDEX,
        sample=SAMPLE,
        ref=REF    
    }

    File pileup_bed = run_modkit.pileup_5hmC_bed

    if (defined(GENOME_FILE)){
        call create_bedgraph {
            input:
            genome_file=select_first([GENOME_FILE]),
            sample=SAMPLE,
            ref=REF,
            modbed=pileup_bed
        }
    }

    output {
        File pileup_5hmC = pileup_bed
        File? ML_histogram = plot_ML_hist.out
        File? pileup_5hmC_bedgraph = create_bedgraph.bedgraph
    }
}


task plot_ML_hist {
    input {
        File modbam
        File modbam_index
        String sample
        Int buckets = 128
        Int memSizeGB = 50
        Int threadCount = 64
        Int diskSizeGB = 5*round(size(modbam, "GB")) + 20
    }

    command <<<
        set -eux -o pipefail
        set -o xtrace

        # link the modbam to make sure it's index can be found
        ln -s ~{modbam} input.bam
        ln -s ~{modbam_index} input.bam.bai

        # Generate ML distribution (Default: 128 buckets)
        mkdir output_dir/
        modkit sample-probs input.bam -t ~{threadCount} \
            --only-mapped --hist ~{"--buckets " + buckets} \
            --force --prefix ~{sample} -o output_dir/
        
        # Plot
        Rscript /opt/scripts/plot-dist.R output_dir/~{sample}_probabilities.tsv output_dir/~{sample}.ML_hist.png
    >>>

    output {
        File out = "output_dir/~{sample}.ML_hist.png"
    }

    runtime {
        memory: memSizeGB + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSizeGB + " SSD"
        docker: "quay.io/shnegi/modkit:latest"
        preemptible: 1
    }
}


task run_modkit {
    parameter_meta {
        OUTPUT_LOG: "(OPTIONAL) Generate pileup log ?? Default: false"
        CPG: "(OPTIONAL) Restrict pileup to cpg sites ?? Default: true"
        MOD_THRESHOLDS: "(OPTIONAL) Custom mod thresholds. Provide in full format. Eg --mod-thresholds m:0.95 --mod-thresholds h:0.8"
        OTHERARGS: "(OPTIONAL) Additional optional arguments for modkit"
        HCMOD_COV: "(OPTIONAL) High-confidence 5hmC mod valid_cov (number of passed sites) threshold. Default: 1"
        HCMOD_PERC: "(OPTIONAL) High-confidence 5hmC percent modification threshold. Default: 80"
    }

    input {
        File modbam
        File modbam_index
        String sample
        File ref
        Boolean output_log = false
        Boolean cpg = true
        String mod_thresholds = ""
        String otherArgs = ""
        Int hcmod_cov = 1
        Float hcmod_perc = 80
        Int memSizeGB = 100
        Int threadCount = 64
        Int diskSizeGB = 5*round(size(modbam, "GB")) + 20
    }

    command <<<
        # exit when a command fails, fail with unset variables, print commands before execution
        set -eux -o pipefail
        set -o xtrace

        # link the modbam to make sure it's index can be found
        ln -s ~{modbam} input.bam
        ln -s ~{modbam_index} input.bam.bai

        # Run modkit pileup
        modkit pileup \
            -t ~{threadCount} --max-depth 800000  \
            ~{true="--cpg" false="" cpg} ~{mod_thresholds} \
            ~{true="--log-filepath pileup.log" false="" output_log} \
            --ref ~{ref} --only-tabs ~{otherArgs}\
            input.bam ~{sample}_pileup.bed

        # Filter mods to generate a high-confidence set
        #cov=~{hcmod_cov}; perc=~{hcmod_perc}
        cat ~{sample}_pileup.bed | awk '$4~"h" && $10>= ~{hcmod_cov} && $11>= ~{hcmod_perc}' > ~{sample}_5hmC_pileup.bed

    >>>

    output {
        File pileup_5hmC_bed = "~{sample}_5hmC_pileup.bed"
    }

    runtime {
        memory: memSizeGB + " GB"
        cpu: threadCount
        disks: "local-disk " + diskSizeGB + " SSD"
        docker: "quay.io/shnegi/modkit:latest"
        preemptible: 1
    }
}


task create_bedgraph {
    parameter_meta {
        WINDOW: "(OPTIONAL) Window length for counting mods. Default: 2000"
        SLIDE: "(OPTIONAL) Slide length. Default: 500"
    }

    input {
        File modbed
        File genome_file
        String sample
        File ref
        Int window = 2000
        Int slide = 500
        Int memSizeGB = 100
        Int diskSizeGB = 5*round(size(ref, "GB")) + 20
    }

    command <<<
        # exit when a command fails, fail with unset variables, print commands before execution
        set -eux -o pipefail
        set -o xtrace

        ## Make the BED file with sliding windows, using given parameters (Default: w=2000, s=500)
        bedtools makewindows -g ~{genome_file} -w ~{window} -s ~{slide} > ~{sample}.windows.bed
        ## Intersect with high-confidence 5hmC mods to count mods in each window
        bedtools intersect -loj -c -a ~{sample}.windows.bed -b ~{modbed} | awk '$4!=0' > ~{sample}.5hmC_counts.bedgraph
    >>>

    output {
        File bedgraph = "~{sample}.5hmC_counts.bedgraph"
    }

    runtime {
        memory: memSizeGB + " GB"
        disks: "local-disk " + diskSizeGB + " SSD"
        docker: "quay.io/biocontainers/bedtools:2.31.1--hf5e1c6e_0"
        preemptible: 1
    }
}