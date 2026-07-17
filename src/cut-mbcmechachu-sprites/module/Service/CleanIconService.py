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
            img.background_color = Color('transparent')

            actualBackgroundColor = self.__getFirstNonDotPixelColor(iconFile)

            # Remove the dot by drawing a rectangle with the background color
            with Drawing() as draw:
                draw.fill_color = actualBackgroundColor
                draw.rectangle(
                    left=self.config.spriteIconDot.left,
                    top=self.config.spriteIconDot.top,
                    width=self.config.spriteIconDot.width,
                    height=self.config.spriteIconDot.height,
                )
                draw(img)
            
            # Make the background color fully transparent
            img.transparent_color(actualBackgroundColor, alpha=0.0, fuzz=0.10)

            img.save(filename=cleanIconFile)

        return cleanIconFile

    def __getFirstNonDotPixelColor(self, numberFile):
        with Image(filename=numberFile) as img:
            x = self.config.spriteIconDot.width + self.config.spriteIconDot.left + 1
            y = self.config.spriteIconDot.height + self.config.spriteIconDot.top + 1

            return img[x, y]