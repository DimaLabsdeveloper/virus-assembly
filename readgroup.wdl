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

import "tasks/biopet.wdl" as biopet
import "QC/QC.wdl" as QC
import "tasks/bwa.wdl" as bwa

workflow readgroup {
    Array[File] sampleConfigs
    String readgroupId
    String libraryId
    String sampleId
    String outputDir

    call biopet.SampleConfig as config {
        input:
            inputFiles = sampleConfigs,
            sample = sampleId,
            library = libraryId,
            readgroup = readgroupId,
            tsvOutputPath = readgroupId + ".config.tsv"
    }

    call QC.QC as qc {
        input:
            read1 = config.values.R1,
            read2 = config.values.R2,
            outputDir = outputDir + "qc"
    }

    output {
        File read1afterQC = qc.read1afterQC
        File? read2afterQC = qc.read2afterQC
    }

}

