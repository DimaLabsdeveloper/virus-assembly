package biowdl.test.virusassembly

import java.io.File

import nl.biopet.utils.biowdl.multisample.MultisamplePipeline

trait VirusAssembly extends MultisamplePipeline {

  override def inputs: Map[String, Any] =
    super.inputs ++
      Map(
        "pipeline.outputDir" -> outputDir.getAbsolutePath,
        "pipeline.gamsInputs" -> Map()
      )

  def startFile: File = new File("./pipeline.wdl")
}
