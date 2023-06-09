from pathlib import Path

class FileInput:

    @staticmethod
    def check(filePath: str):
        path = Path(filePath)

        if not path.is_file():
            raise Exception(f'Input file {filePath} not found')
        
        return True