#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path getcwd);

our $VERSION = '1.1.1';
our @TARGETS = qw(
	iossimulator-xcrun
	ios64-xcrun
	ios-xcrun
);

sub explain_target_name
{
	my $name = shift;
	$name=~s/-sim/simulator-/;
	$name=~s/-.*//;
	my $platform = $name;
	$platform = "iOS" if ($name=~m/^ios.*/);
	return  ($name, $platform);
}

sub download
{
	my $file = shift;
	my $url = "https://www.openssl.org/source/$file";
	return 1 if ( -e $file);
	system("curl -k -L -o $file \"$url\"");
	return $? == 0;
}

sub build
{
	my $file = shift;
	mkdir('src');
	mkdir('build');

	my %outfiles;

	my $pwd = getcwd();
	foreach my $t(@TARGETS)
	{
		my ($name, $platform) = explain_target_name($t);
		if (! defined($outfiles{$platform}))
		{
			$outfiles{$platform} = {'ssl'=>[], 'crypto'=>[], include=>''};
		}

		#extract.
		if (! -e "$pwd/src/$name/openssl-$VERSION/Configure")
		{
			mkdir("$pwd/src/$name");
			mkdir("$pwd/build/$name");
			system("cd \"$pwd/src/$name\" && tar -xzf ../../$file");
			if ($? != 0) {return 0;}
		}

		#Configure
		my $logf = "\"$pwd/build/$name/build-$VERSION.log\"";
		chdir("$pwd/src/$name/openssl-$VERSION");
		if (! -e 'Makefile')
		{
			system("./Configure $t --prefix=\"$pwd/build/$name\" no-deprecated no-async no-shared > $logf");
			if ($? != 0) {return 0;}
			print STDERR "Configure for $t DONE!\n";
		}

		if (! -e "$pwd/build/$name/lib/libssl.a" || ! -e "$pwd/build/$name/lib/libcrypto.a")
		{
			# make
			my $CPU = `sysctl -n hw.ncpu`;
			$CPU=~s/\s+$//sg;
			print STDERR "making with $CPU threads. Log at $logf\n";
			system("make -j$CPU >$logf 2>&1");
			if ($? != 0) {return 0;}
			print STDERR "make DONE!\n";

			# make install
			print STDERR "make install_sw\n";
			system("make install_sw >$logf 2>&1");
			if ($? != 0) {return 0;}
			print STDERR "make install_sw DONE!\n";
		}
		push @{$outfiles{$platform}->{ssl}}, "$pwd/build/$name/lib/libssl.a";
		push @{$outfiles{$platform}->{crypto}}, "$pwd/build/$name/lib/libcrypto.a";
		$outfiles{$platform}->{include} = "$pwd/build/$name/include";
		chdir($pwd);
	}

	mkdir("bin");
	foreach my $p(keys(%outfiles))
	{
		my $cmd;
		mkdir("bin/$p");
		mkdir("bin/$p/lib");

		$cmd = "lipo -create -output bin/$p/lib/libssl.a";
		print STDERR "creating bin/$p/lib/libssl.a\n";
		foreach (@{$outfiles{$p}->{ssl}})
		{
			print "  $_\n";
			$cmd .= " \"$_\"";
		}
		system("$cmd");

		$cmd = "lipo -create -output bin/$p/lib/libcrypto.a";
		print STDERR "creating bin/$p/lib/libcrypto.a\n";
		foreach (@{$outfiles{$p}->{crypto}})
		{
			print "  $_\n";
			$cmd .= " \"$_\"";
		}
		system("$cmd");
		my $inc = $outfiles{$p}->{include};
		system("cp -R \"$inc\" \"bin/$p/\"");
	}
	return 1;
};

sub main
{
	my $file = "openssl-${VERSION}.tar.gz";
	download($file) || return 1;
	build($file) || return 1;
	return 0;
}

exit(&main);

