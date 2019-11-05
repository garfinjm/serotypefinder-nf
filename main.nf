#!/usr/bin/env nextflow

readsQueue = Channel.fromFilePairs( ['./*_L001_R{1,2}_001.fastq.gz','./*_{1,2}.fastq','./*_{1,2}.fastq.gz'] )

params.cpus = 8
params.memory = 15
seqycleanforks = params.cpus - 1

resultsDir=workflow.launchDir+"/results"

process runSeqyclean {

    storeDir resultsDir+'/cleanedreads'
	stageInMode = 'copy'
	maxForks = seqycleanforks

	input:
	set id, file(fastq_names) from readsQueue

	output:
	set val(id), file("${id}_clean_PE1.fastq.gz"), file("${id}_clean_PE2.fastq.gz") into cleanreadsQueue

	"""
    seqyclean -gz -minlen 25 -qual -c /Adapters_plus_PhiX_174.fasta -1 ${fastq_names[0]} -2 ${fastq_names[1]} -o ${id}_clean
	"""
}

process runShovill {

    storeDir resultsDir+'/shovill'
	stageInMode = 'copy'
	maxForks = 1

	input:
	set id, file(R1), file(R2) from cleanreadsQueue

	output:
	set val(id), file("${id}.fasta") into quastQueue, serotypefinderQueue

	"""
    shovill --outdir . --force --cpus ${params.cpus} --ram ${params.memory} --gsize 5000000 --R1 ${R1} --R2 ${R2};
    mv contigs.fa ${id}.fasta
	"""
}

process runQuast {

    storeDir resultsDir+'/quast'
	stageInMode = 'copy'

	input:
	file assemblies from quastQueue.collect()

	output:
	file "report.tsv" into quastResults
	file "report.html" into quastReports

	"""
	quast.py -o . -t ${params.cpus} ${assemblies}
	"""
}

process runSerotypefinder {

    storeDir resultsDir+'/serotypefinder'
	stageInMode = 'copy'

	input:
	set id, file(assembly) from serotypefinderQueue

	output:
	set val(id), file("sero-${id}/*.*") into serotypefinderPredictions

	"""
	serotypefinder.pl -d /serotypefinder/database -s ecoli -k 85 -l 0.60 -i ${assembly} -o sero-${id}
	"""
}
