pub fn main() {
    klask::run_derived::<dfx::CliOpts, _>(klask::Settings::default(), |_| {});
}
