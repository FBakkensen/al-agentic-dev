namespace Issue75.LiveCoverage;

codeunit 74102 "Live Coverage Fail Tests"
{
    Subtype = Test;

    [Test]
    procedure IntentionalFailureAfterMainCode()
    var
        CoverageSpine: Codeunit "Live Coverage Spine";
        Result: Integer;
    begin
        Result := CoverageSpine.CoveredPath(false);
        if Result <> 42 then
            Error('Expected 42, got %1.', Result);
        Error('Intentional issue 75 live proof failure.');
    end;
}
