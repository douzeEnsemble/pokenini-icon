from pathlib import Path

class SpriteFileInput:

    @staticmethod
    def check(spritePath: str):
        path = Path(spritePath)

        if not path.is_file():
            raise Exception(f'Input file {spritePath} not found')
        
        return True