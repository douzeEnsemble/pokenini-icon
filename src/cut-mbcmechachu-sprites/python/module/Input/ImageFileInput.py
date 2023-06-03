from pathlib import Path

class ImageFileInput:

    @staticmethod
    def check(imagePath: str):
        path = Path(imagePath)

        if not path.is_file():
            raise Exception(f'Input file {imagePath} not found')
        
        return True