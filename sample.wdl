version 1.0

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
import "structs.wdl" as structs

workflow Sample {
    input {
        Sample sample
        String sampleDir
        VirusAssemblyInputs virusAssemblyInputs
    }

    scatter (lb in sample.libraries) {
        call libraryWorkflow.Library as library {
            input:
                libraryDir = sampleDir + "/lib_" + lb.id,
                library = lb,
                sample = sample,
                virusAssemblyInputs = virusAssemblyInputs
        }
    }

    # Do the per sample work and the work over all the library
    # results below this line.

    # The below code assumes that library.reads1 and library.reads2 are in the same order
    call common.ConcatenateTextFiles as concatenateLibraryReads1 {
        input:
            fileList = flatten(library.reads1),
            combinedFilePath = sampleDir + "/combinedReads1-" + sample.id + ".fq.gz",
            zip = true,
            unzip = true
        }

    if (defined(library.reads2)) {
        call common.ConcatenateTextFiles as concatenateLibraryReads2 {
            input:
                fileList = flatten(select_all(library.reads2)),
                combinedFilePath = sampleDir + "/combinedReads2-" + sample.id + ".fq.gz",
                zip = true,
                unzip = true
            }
        }

    File combinedReads1 = concatenateLibraryReads1.combinedFile
    File? combinedReads2 = concatenateLibraryReads2.combinedFile

    Int seed = select_first([virusAssemblyInputs.downsampleSeed, 11])

    if (defined(virusAssemblyInputs.fractionOrNumber)) {
        call seqtk.Sample as subsampleRead1 {
            input:
                sequenceFile = combinedReads1,
                fractionOrNumber = select_first([virusAssemblyInputs.fractionOrNumber]),
                seed = seed,
                outFilePath = sampleDir + "/subsampling/subsampledReads1.fq.gz", #Spades needs a proper extension or it will crash
                zip = true
        }
    }

    if (defined(combinedReads2) && defined(virusAssemblyInputs.fractionOrNumber)) {
        # Downsample read2
        call seqtk.Sample as subsampleRead2 {
            input:
                sequenceFile = select_first([combinedReads2]),
                fractionOrNumber = select_first([virusAssemblyInputs.fractionOrNumber]),
                seed = seed,
                outFilePath = sampleDir + "/subsampling/subsampledReads2.fq.gz",  #Spades needs a proper extension or it will crash
                zip = true
            }
    }

    # Call spades for the de-novo assembly of the virus.
    call spades.Spades as spades {
        input:
            read1 = select_first([subsampleRead1.subsampledReads, combinedReads1]),
            read2 = if (defined(virusAssemblyInputs.fractionOrNumber)) then subsampleRead2.subsampledReads else combinedReads2,
            outputDir = sampleDir + "/spades"
        }

    output {
        File spadesContigs = spades.contigs
        File spadesScaffolds = spades.scaffolds
    }
}