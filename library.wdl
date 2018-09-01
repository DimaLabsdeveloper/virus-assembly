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

import "readgroup.wdl" as readgroupWorkflow
import "tasks/biopet.wdl" as biopet
import "tasks/common.wdl" as common
import "structs.wdl" as structs

workflow Library {
    input {
        Sample sample
        Library library
        String libraryDir
        VirusAssemblyInputs virusAssemblyInputs
    }

    scatter (rg in library.readgroups) {
        call readgroupWorkflow.Readgroup as readgroup {
            input:
                readgroupDir = libraryDir + "/rg_" + rg.id,
                readgroup = rg,
                library = library,
                sample = sample,
                virusAssemblyInputs = virusAssemblyInputs
        }
    }

    # Add the jobs that are done per library and over the results of
    # all the readgroups below this line.

    # The below code assumes that QC.read1afterQC and QC.read2afterQC are in the same order.
    call common.ConcatenateTextFiles as concatenateReads1 {
        input:
            fileList = readgroup.read1afterQC,
            combinedFilePath = libraryDir + "/combinedReads1-" + library.id
        }

    if (length(select_all(readgroup.read2afterQC)) > 0) {
        call common.ConcatenateTextFiles as concatenateReads2 {
            input:
                fileList = select_all(readgroup.read2afterQC),
                combinedFilePath = libraryDir + "/combinedReads2-" + library.id
            }
        }

    output {
        File reads1 = concatenateReads1.combinedFile
        File? reads2 = concatenateReads2.combinedFile
    }
}
