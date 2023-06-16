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
        count = 0

        for rootDir, curDir, files in os.walk(spritesDir):
            total = len(files)
            print(f'Start for {total} sprites')
            for file in files:
                isDone = self.spriteToIconService.transform(
                    spritesDir+'/'+file, 
                    targetDir
                )

                if isDone:
                    doneCount += 1

                count += 1
                # Display only each 10 percent
                if ((count % round(total / 10)) == 0):
                    print(f'{count}/{total}')

            notDoneCount = total - doneCount

            print(f'End with {doneCount} done of {total} total')

            return doneCount, notDoneCount
        
        return 0, 0

        
