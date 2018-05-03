# Copyright (c) 2018 Sequencing Analysis Support Core - Leiden University Medical Center
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import "library.wdl" as libraryWorkflow
import "tasks/biopet.wdl" as biopet
import "tasks/common.wdl" as common
import "tasks/seqtk.wdl" as seqtk
import "tasks/spades.wdl" as spades

workflow sample {
    Array[File] sampleConfigs
    String sampleId
    String outputDir
    Int? downsampleNumber
    Int? downsampleSeed = 11

    # Get the library configuration
    call biopet.SampleConfig as librariesConfigs {
        input:
            inputFiles = sampleConfigs,
            sample = sampleId,
            jsonOutputPath = sampleId + ".config.json",
            tsvOutputPath = sampleId + ".config.tsv"
    }

    # Do the work per library.
    # Modify library.wdl to change what is happening per library.
    scatter (libraryId in librariesConfigs.keys) {
        if (libraryId != "") {
            call libraryWorkflow.library as library {
                input:
                    outputDir = outputDir + "/lib_" + libraryId,
                    sampleConfigs = sampleConfigs,
                    libraryId = libraryId,
                    sampleId = sampleId
            }
        }
    }


    # Do the per sample work and the work over all the library
    # results below this line.

    # The below code assumes that library.reads1 and library.reads2 are in the same order
    call common.concatenateTextFiles as concatenateReads1 {
        input:
            fileList = library.reads1,
            combinedFilePath = outputDir + "/combinedReads1-" + sampleId
        }

    if (length(select_all(library.reads2)) > 0) {
        call common.concatenateTextFiles as concatenateReads2 {
            input:
                fileList = select_all(library.reads2),
                combinedFilePath = outputDir + "/combinedReads2-" + sampleId
            }
        }
    File combinedReads1 = concatenateReads1.combinedFile
    File? combinedReads2 = concatenateReads2.combinedFile

    call seqtk.sample as subsampleRead1 {
        input:
            sequenceFile=combinedReads1,
            number=downsampleNumber,
            seed=downsampleSeed,
            outFilePath=outputDir + "/subsampling/subsampledReads1.fq.gz", #Spades needs a proper extension or it will crash
            zip=true
    }

    if (defined(combinedReads2)) {
        # Downsample read2
        call seqtk.sample as subsampleRead2 {
            input:
                sequenceFile=select_first([combinedReads2]),
                number=downsampleNumber,
                seed=downsampleSeed,
                outFilePath=outputDir + "/subsampling/subsampledReads2.fq.gz",  #Spades needs a proper extension or it will crash
                zip=true
            }
    }

    # Call spades for the de-novo assembly of the virus.
    call spades.spades {
        input:
            read1=subsampleRead1.subsampledReads,
            read2=subsampleRead2.subsampledReads,
            outputDir=outputDir + "/spades"
        }
    output {
        Array[String] libraries = librariesConfigs.keys
        File spadesContigs = spades.contigs
        File spadesScaffolds = spades.scaffolds
    }
}