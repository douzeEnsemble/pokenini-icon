import os

from pathlib import Path

from wand.image import Image
from wand.drawing import Drawing
from wand.color import Color

from module.Entity.Config.Config import Config
from module.Util.FileDir import FileDir

class RenameIconService:
    def __init__(self, configFile):
        self.config = Config(configFile)

    def rename(self, iconFile, newFileName, targetDir = 'temp/rename'):
        FileDir.createDirs(targetDir)

        iconFilePath = Path(iconFile)

        newIconFile = targetDir+'/'+newFileName+iconFilePath.suffix

        os.rename(iconFile, newIconFile)