namespace Issue75.LiveCoverage;

codeunit 74101 "Live Coverage Pass Tests"
{
    Subtype = Test;

    [Test]
    procedure PassingTest()
    var
        CoverageSpine: Codeunit "Live Coverage Spine";
        Result: Integer;
    begin
        Result := CoverageSpine.CoveredPath(false);
        if Result <> 42 then
            Error('Expected 42, got %1.', Result);
    end;
}
