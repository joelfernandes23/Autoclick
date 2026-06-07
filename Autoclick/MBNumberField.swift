import AppKit

@objc(MBNumberField)
@objcMembers
final class MBNumberField: NSTextField {
    @IBOutlet weak var stepper: NSStepper!

    private var oldValue = 0

    override var integerValue: Int {
        get { super.integerValue }
        set {
            super.stringValue = String(newValue)
            oldValue = super.integerValue
        }
    }

    override func textDidChange(_ notification: Notification) {
        if Double(integerValue) > stepper.maxValue || Double(integerValue) < stepper.minValue {
            integerValue = oldValue
        } else {
            integerValue = integerValue
        }

        oldValue = integerValue
        syncWithStepper()
        delegate?.controlTextDidChange?(notification)
    }

    @IBAction func step(_ sender: Any) {
        guard let control = sender as? NSControl else { return }
        integerValue = control.integerValue
    }

    func syncWithStepper() {
        stepper.integerValue = integerValue
    }
}
