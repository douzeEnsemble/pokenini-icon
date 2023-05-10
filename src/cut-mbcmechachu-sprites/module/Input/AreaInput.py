from module.Entity.Area.CompleteArea import CompleteArea
from module.Entity.Area.ThreeLinesArea import ThreeLinesArea
from module.Entity.Area.LineArea import LineArea
from module.Entity.Area.SampleArea import SampleArea

class AreaInput:

    @staticmethod
    def get(type: str):
        match type:
            case 'complete':
                return CompleteArea()
            case '3lines':
                return ThreeLinesArea()
            case 'line':
                return LineArea()
            case 'sample':
                return SampleArea()
            case _:
                return CompleteArea()
