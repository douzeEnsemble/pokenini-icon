from wand.image import Image

from module.Entity.Config.Config import Config
from module.Util.FileDir import FileDir

class CropSpriteService:

    def __init__(self, configFile):
        self.config = Config(configFile)

    def crop(self, spriteFile, outputDir):
        FileDir.createDirs(outputDir)

        with Image(filename=spriteFile) as original:
            cols = round(original.width / self.config.spriteFull.width)
            rows = round(original.height / self.config.spriteFull.height)

            for col in range(cols):
                for row in range(rows):
                    self.__crop(original, outputDir, col, row)

    def __crop(self, original, outputDir, col, row):
        with original.clone() as copy:
            cropWidth = self.config.spriteFull.width
            cropHeight = self.config.spriteFull.height

            cropLeft = col * cropWidth
            cropTop = row * cropHeight

            copy.crop(
                cropLeft,
                cropTop,
                width=cropWidth, 
                height=cropHeight
            )

            copy.save(filename=outputDir+'/sprite-'+str(row)+'-'+str(col)+'.png')