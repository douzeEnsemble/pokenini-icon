import os

from module.Entity.Config.Config import Config
from module.Service.SpriteToIconService import SpriteToIconService

class SpritesToIconsService:

    def __init__(self, configFile, spriteToIconService: SpriteToIconService):
        self.config = Config(configFile)
        self.spriteToIconService = spriteToIconService

    def cut(self, spritesDir, targetDir) -> tuple[int, int]:
        doneCount = 0
        notDoneCount = 0

        for rootDir, curDir, files in os.walk(spritesDir):
            total = len(files)
            for file in files:
                isDone = self.spriteToIconService.transform(
                    spritesDir+'/'+file, 
                    targetDir
                )

                if isDone:
                    doneCount += 1
                    print(f'{doneCount}/{total}')

            notDoneCount = total - doneCount

        return doneCount, notDoneCount
