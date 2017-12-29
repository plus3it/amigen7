# Background 

This project originated as a simple toolkit to help automate the creation of generic Enterprise Linux AMIs. The resultant AMIs were necessary to support a larger automation project that spanned multiple AWS regions - commercial and GovCloud.

At the project's origination, there was a particular lack of AMI uniformity across the offerings from Red Hat and CentOS.org. These tools ensure that resultant Red Hat and CentOS AMIs are 99% identical from an RPM-manifest, AWS-toolset, partitioning and initial-user perspective. Primary differences between the Red Hat and CentOS AMIs are resultant of concessions to leveraging the RHUI RPM repositories.

The overarching automation project was focused on implementing DISA STIGs within VMs deployed to AWS environment(s). At the time the project came into existence, there were not AMIs that could check off the various STIG boxes for "<DIRECTORY> must be on its own filesystem". This project sought to address that.

The overarching automation project also included a mandate for the inclusion of anti-virus (A/V) scanners in all production-ready systems. Most of the A/V scanners exacted a heavy system impact when the /tmp filesystem was hosted on HDD-backed storage. As a result, the produced AMIs have /tmp on tmpfs.

Lastly, ext4 was chosen over XFS for flexibility reasons: you can't shrink XFS filesystems. Yes, root-filesystems hosted on AWS-hosted VMs are mostly not practical to attempt to shrink. However, use of ext4 enables this use-case for determined system owners.

# How to Contribute

Because of the above background, specific design decisions were made. Further, because this project had an organic origination (read: "there was no originally-specified demand for this particular project; however, the realities of the overarching project effectively demanded its existence"). As a result the implementation was done with no pre-allocated time for doing so.

It would be great if users of this project could help by identifying gaps that our specific use-cases have not uncovered. In an ideal world, that help would come in the form of code-contributions (via pull-requests). Next-best option is submitting Issues identifying gaps with as great of detail as possible - preferably inclusive of suggestions for mitigating those gaps.

Because of the aforementioned time-constraints, we are already aware that the project's scripts contain a higher-than-desired degree of "brittleness". Some of this is hidden by another project. However, because that other project acts as an overlay to this project, contributions that help address the current brittleness would be greatly appreciated.

Similarly, we are aware that, while the tools _can_ be used to produce unpartitioned AMIs (we use them to produce "recovery" AMIs), those funtionalities are even more brittle and apt to lead to wailing and gnashing-of-teeth than the specifially-designed-for functionalities. Please feel free to improve those functionalities or even just provide further "how not to blow yourself up" documentation.

Otherwise, in the interest of full disclosure, the fruits of this automation-effort are openly provided on a wholly "as-is" basis. Individuals who have stumbled on this project and find deficiencies in it are invited to help us enhance the project for broader usability (as described above).

## Testing

This project leverages a fairly bare-bones test-suite performed through Travis CI's [online testing framework](https://travis-ci.org/). As of this contribution-guideline document's last edit date, the only things being tested for are de-linting for shell (BASH) style and syntax checking via the shellchecker utility. Shell style- and syntax-checking are done via [Koalaman's shellcheck utilities](https://github.com/koalaman/shellcheck) (functionality which is also available via copy/paste at https://www.shellcheck.net/). The current test "recipies" are found in the `.travis.yml` file found in the project's root directory.

## Submitting Changes

In general, we prefer changes be offered in the form of tested pull-requests. Prior to opening a pull-request, we also prefer that an associated issue be opened - you can request that you be assigned or otherwise granted ownership in that issue. The submitted pull-request should reference the previously-opened issue. The pull-request should include a clear list of what changes are being offered (read more about [pull requests](http://help.github.com/pull-requests/)). The received PR should show green in Travis (see the above "Testing" section). If the received PR doesn't show green in Travis, it will be rejected. It is, therefore, recommended that prior to submitting a pull request, Travis will have been leveraged to pre-validate changes in the submitter's fork.

Feel free to enhance the Travis-based checks as desired. Modifications to the `.travis.yml` received via a PR will be evaluated for inclusion as necessary. If other testing frameworks are preferred, please feel free to add them via a PR ...ensuring that the overall PR still passes the existing Travis CI framework. Any way you slice it, improvements in testing are great. We would be very glad of receiving and evaluating any testing-enhancements offered.

Please ensure that commits included in the PR are performed with both clear and concise commit messages. One-line messages are fine for small changes. However, bigger changes should look like this:

    $ git commit -m "A brief summary of the commit
    >
    > A paragraph describing what changed and its impact."

## Coding conventions

Start by reading the existing code. Things are fairly straight-forward - or at least as straight-forward as BASH can be fore certain types of tasks.  We optimize for narrower terminal widths - typically 80-characters (the individual who originated the project has some ooooold habits) but sometimes 120-character widths may be found. We also optimize for UNIX-style end-of-line. Please ensure that your contributions line-ends use just a line-feed (lf) rather than a Windows-style carriage-return/line-feed (crlf) end-of-line. Note that the project-provided `.editorconfig` file should help ensure this behavior.

Overall, shell script conventions are fairly minimal
    * Pass the shellchecker validity tests
    * Use three-space indent-increments for basic indenting
    * If breaking across lines, indent following lines by two-spaces (to better differentiate from standard indent-blocks) - obviously, this can be ignored for here-documents..
    * Code should be liberally-commented.
       * Use "# " or "## " to prepend.
       * Indent comment-lines/blocks to line up with the blocks of code being commented
    * Anything not otherwise specified - either explicitly as above or implicitly via pre-existing code - pick an element-style and be consistent with it.

## Additonal Notes

As indicated previously, this project serves an overaching goal of fostering STIG compliance. As such, the resultant AMIs strive for as close to an @core type of installation as possible. If desired/offered changes require additional RPMs be added to what's already in the project, please justify their inclusion (that is, answer the question "what value do these provide that offsets the potential increase in attack-surface or otherwise causing an IA accreditor to raise an eyebrow").
