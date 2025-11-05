from pathlib import Path

from wand.image import Image

from module.Entity.Config.Config import Config
from module.Util.FileDir import FileDir

class SplitSpriteService:

    def __init__(self, configFile):
        self.config = Config(configFile)

    def split(self, spriteFile, outputDir):
        FileDir.createDirs(outputDir)

        path = Path(spriteFile)
        spriteName = path.name
        spriteCode = spriteName.replace('sprite-', '')
        
        with Image(filename=spriteFile) as original:
            numberFile = self.__cutNumber(original, outputDir, spriteCode)
            iconFile = self.__cutIcon(original, outputDir, spriteCode)

            return numberFile, iconFile

    def __cutNumber(self, original, outputDir, spriteCode):
        with original.clone() as copy:
            copy.strip()
            cropWidth = self.config.spriteNumber.width
            cropHeight = self.config.spriteNumber.height
            cropLeft = self.config.spriteNumber.left
            cropTop = self.config.spriteNumber.top

            copy.crop(
                cropLeft,
                cropTop,
                width=cropWidth, 
                height=cropHeight
            )

            outputFile = outputDir+'/number-'+spriteCode
            copy.save(filename=outputFile)

            return outputFile

    def __cutIcon(self, original, outputDir, spriteCode):
        with original.clone() as copy:
            cropWidth = self.config.spriteIcon.width
            cropHeight = self.config.spriteIcon.height
            cropLeft = self.config.spriteIcon.left
            cropTop = self.config.spriteIcon.top

            copy.crop(
                cropLeft,
                cropTop,
                width=cropWidth, 
                height=cropHeight
            )

            outputFile = outputDir+'/icon-'+spriteCode
            copy.save(filename=outputFile)

            return outputFile