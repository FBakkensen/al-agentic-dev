namespace Issue75.LiveCoverage;

codeunit 74100 "Live Coverage Spine"
{
    procedure CoveredPath(UseAlternate: Boolean): Integer
    var
        Result: Integer;
    begin
        Result := 40;
        if UseAlternate then
            Result := 99;
        Result += 2;
        exit(Result);
    end;

    procedure UncoveredPath(): Integer
    var
        Result: Integer;
    begin
        Result := 100;
        Result += 23;
        exit(Result);
    end;
}
