import os

from pathlib import Path

from module.Entity.Config.Config import Config
from module.Util.FileDir import FileDir

class RenameIconService:
    def __init__(self, configFile):
        self.config = Config(configFile)

    def rename(self, iconFile, newFileName, targetDir):
        FileDir.createDirs(targetDir)

        iconFilePath = Path(iconFile)

        newIconFile = targetDir+'/'+newFileName+iconFilePath.suffix

        os.rename(iconFile, newIconFile)