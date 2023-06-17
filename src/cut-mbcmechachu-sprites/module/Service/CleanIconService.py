from pathlib import Path

from wand.image import Image
from wand.drawing import Drawing
from wand.color import Color

from module.Entity.Config.Config import Config
from module.Util.FileDir import FileDir

class CleanIconService:
    def __init__(self, configFile):
        self.config = Config(configFile)

    def clean(self, iconFile, targetDir):
        FileDir.createDirs(targetDir)
            
        iconFilePath = Path(iconFile)
        cleanIconFile = targetDir+'/c_'+iconFilePath.name

        with Image(filename=iconFile) as img:
            img.alpha_channel = True
            img.background_color = Color('transparent')

            with Drawing() as draw:
                draw.fill_color = self.__getFirstNonDotPixelColor(iconFile)
                draw.rectangle(
                    self.config.spriteIconDot.left,
                    self.config.spriteIconDot.top,
                    self.config.spriteIconDot.width,
                    self.config.spriteIconDot.height,
                )
                draw(img)
            
            img.transparent_color(self.__getFirstNonDotPixelColor(iconFile), alpha=0.0, fuzz=0.10)

            img.save(filename=cleanIconFile)

        return cleanIconFile

    def __getFirstNonDotPixelColor(self, numberFile):
        with Image(filename=numberFile) as img:
            x = self.config.spriteIconDot.width + self.config.spriteIconDot.left + 1
            y = self.config.spriteIconDot.height + self.config.spriteIconDot.top + 1

            return img[x, y]